<?php
declare(strict_types=1);

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../helpers/response.php';
require_once __DIR__ . '/../helpers/auth.php';

setupCors();

$pdo = Database::getConnection();
$user = authenticateUser($pdo);
$businessId = (int)$user['business_id'];

$method = $_SERVER['REQUEST_METHOD'];
$data = getRequestData();

try {
    switch ($method) {
        case 'GET':
            // 1. Single sale invoice by ID or invoice_number
            if (!empty($data['id']) || !empty($data['invoice_number'])) {
                $where = !empty($data['id']) ? "s.id = :id" : "s.invoice_number = :invoice_number";
                $paramKey = !empty($data['id']) ? 'id' : 'invoice_number';
                $paramVal = !empty($data['id']) ? (int)$data['id'] : trim((string)$data['invoice_number']);

                $saleStmt = $pdo->prepare("
                    SELECT s.*,
                           c.name AS customer_name, c.phone AS customer_phone, c.address AS customer_address, c.current_balance AS customer_current_balance,
                           b.name AS business_name, b.phone AS business_phone, b.currency, b.address AS business_address
                    FROM sales s
                    LEFT JOIN customers c ON s.customer_id = c.id
                    INNER JOIN businesses b ON s.business_id = b.id
                    WHERE {$where} AND s.business_id = :business_id
                    LIMIT 1
                ");
                $saleStmt->execute([$paramKey => $paramVal, 'business_id' => $businessId]);
                $sale = $saleStmt->fetch(PDO::FETCH_ASSOC);

                if (!$sale) {
                    jsonError('Sale invoice not found.', 404);
                }

                // Fetch sale items
                $itemsStmt = $pdo->prepare("
                    SELECT si.*, p.name AS product_name, p.sku AS product_sku, p.barcode AS product_barcode
                    FROM sale_items si
                    INNER JOIN products p ON si.product_id = p.id
                    WHERE si.sale_id = :sale_id
                ");
                $itemsStmt->execute(['sale_id' => (int)$sale['id']]);
                $sale['items'] = $itemsStmt->fetchAll(PDO::FETCH_ASSOC);

                jsonSuccess($sale, 'Sale invoice details retrieved');
            }

            // 2. Sales list
            $sql = "
                SELECT s.*, c.name AS customer_name, c.phone AS customer_phone,
                       (SELECT COUNT(*) FROM sale_items WHERE sale_id = s.id) AS total_items,
                       (SELECT SUM(quantity) FROM sale_items WHERE sale_id = s.id) AS total_units
                FROM sales s
                LEFT JOIN customers c ON s.customer_id = c.id
                WHERE s.business_id = :business_id
            ";
            $params = ['business_id' => $businessId];

            if (!empty($data['start_date'])) {
                $sql .= " AND DATE(s.created_at) >= :start_date";
                $params['start_date'] = trim((string)$data['start_date']);
            }
            if (!empty($data['end_date'])) {
                $sql .= " AND DATE(s.created_at) <= :end_date";
                $params['end_date'] = trim((string)$data['end_date']);
            }
            if (!empty($data['customer_id'])) {
                $sql .= " AND s.customer_id = :customer_id";
                $params['customer_id'] = (int)$data['customer_id'];
            }
            if (!empty($data['payment_method'])) {
                $sql .= " AND s.payment_method = :payment_method";
                $params['payment_method'] = strtoupper(trim((string)$data['payment_method']));
            }
            if (!empty($data['payment_status'])) {
                $sql .= " AND s.payment_status = :payment_status";
                $params['payment_status'] = strtoupper(trim((string)$data['payment_status']));
            }

            $sql .= " ORDER BY s.id DESC";

            // Limit
            $limit = isset($data['limit']) ? min(100, max(1, (int)$data['limit'])) : 50;
            $offset = isset($data['offset']) ? max(0, (int)$data['offset']) : 0;
            $sql .= " LIMIT {$limit} OFFSET {$offset}";

            $stmt = $pdo->prepare($sql);
            $stmt->execute($params);
            $sales = $stmt->fetchAll(PDO::FETCH_ASSOC);

            jsonSuccess($sales, 'Sales retrieved successfully');
            break;

        case 'POST':
            $items = $data['items'] ?? [];
            if (!is_array($items) || empty($items)) {
                jsonError('Items array is required and cannot be empty.', 422);
            }

            $customerId = !empty($data['customer_id']) ? (int)$data['customer_id'] : null;
            $paymentMethod = strtoupper(trim((string)($data['payment_method'] ?? 'CASH')));
            $discountAmount = isset($data['discount_amount']) ? max(0, (float)$data['discount_amount']) : 0.0;
            $notes = sanitizeString($data['notes'] ?? '');

            // Payment status logic
            if ($paymentMethod === 'CREDIT') {
                $paymentStatus = strtoupper(trim((string)($data['payment_status'] ?? 'UNPAID')));
                if (!$customerId) {
                    jsonError('A registered customer is required for credit (Udhaar) sales.', 422);
                }
            } else {
                $paymentStatus = strtoupper(trim((string)($data['payment_status'] ?? 'PAID')));
            }

            $amountPaid = isset($data['amount_paid']) ? (float)$data['amount_paid'] : ($paymentStatus === 'PAID' ? null : 0.0);

            // Fetch and validate all products involved
            $productIds = array_map(fn($item) => (int)($item['product_id'] ?? 0), $items);
            $productIds = array_filter($productIds, fn($id) => $id > 0);

            if (empty($productIds)) {
                jsonError('Invalid product IDs provided in items.', 422);
            }

            $inPlaceholders = implode(',', array_fill(0, count($productIds), '?'));
            $prodStmt = $pdo->prepare("
                SELECT id, name, cost_price, selling_price, stock_quantity
                FROM products
                WHERE id IN ({$inPlaceholders}) AND business_id = ? AND is_active = 1
            ");
            $prodStmt->execute([...$productIds, $businessId]);
            $productsDb = [];
            foreach ($prodStmt->fetchAll(PDO::FETCH_ASSOC) as $p) {
                $productsDb[(int)$p['id']] = $p;
            }

            $pdo->beginTransaction();

            $totalAmount = 0.0;
            $processedItems = [];

            foreach ($items as $item) {
                $pid = (int)($item['product_id'] ?? 0);
                $qty = isset($item['quantity']) ? (int)$item['quantity'] : 1;

                if ($qty <= 0) {
                    throw new InvalidArgumentException("Quantity for product ID {$pid} must be at least 1.");
                }

                if (!isset($productsDb[$pid])) {
                    throw new InvalidArgumentException("Product ID {$pid} does not exist or is inactive in your inventory.");
                }

                $product = $productsDb[$pid];
                // Use specified unit price if given, otherwise product's default selling price
                $unitPrice = isset($item['unit_price']) ? (float)$item['unit_price'] : (float)$product['selling_price'];
                $costPrice = (float)$product['cost_price'];
                $subtotal = round($unitPrice * $qty, 2);
                $totalAmount += $subtotal;

                $processedItems[] = [
                    'product_id'   => $pid,
                    'product_name' => $product['name'],
                    'quantity'     => $qty,
                    'unit_price'   => $unitPrice,
                    'cost_price'   => $costPrice,
                    'subtotal'     => $subtotal
                ];
            }

            $totalAmount = round($totalAmount, 2);
            $netAmount = max(0, round($totalAmount - $discountAmount, 2));

            // Generate unique invoice number
            $invoiceNumber = 'INV-' . date('Ymd') . '-' . strtoupper(substr(md5(uniqid((string)mt_rand(), true)), 0, 6));

            // Insert Sale
            $saleInsert = $pdo->prepare("
                INSERT INTO sales (business_id, invoice_number, customer_id, total_amount, discount_amount, net_amount, payment_method, payment_status, notes)
                VALUES (:business_id, :invoice_number, :customer_id, :total_amount, :discount_amount, :net_amount, :payment_method, :payment_status, :notes)
            ");
            $saleInsert->execute([
                'business_id'     => $businessId,
                'invoice_number'  => $invoiceNumber,
                'customer_id'     => $customerId,
                'total_amount'    => $totalAmount,
                'discount_amount' => $discountAmount,
                'net_amount'      => $netAmount,
                'payment_method'  => $paymentMethod,
                'payment_status'  => $paymentStatus,
                'notes'           => $notes
            ]);
            $saleId = (int)$pdo->lastInsertId();

            // Insert sale items and deduct stock
            $itemInsert = $pdo->prepare("
                INSERT INTO sale_items (sale_id, product_id, quantity, unit_price, cost_price, subtotal)
                VALUES (:sale_id, :product_id, :quantity, :unit_price, :cost_price, :subtotal)
            ");
            $stockUpdate = $pdo->prepare("
                UPDATE products
                SET stock_quantity = stock_quantity - :quantity
                WHERE id = :id AND business_id = :business_id
            ");

            foreach ($processedItems as $item) {
                $itemInsert->execute([
                    'sale_id'    => $saleId,
                    'product_id' => $item['product_id'],
                    'quantity'   => $item['quantity'],
                    'unit_price' => $item['unit_price'],
                    'cost_price' => $item['cost_price'],
                    'subtotal'   => $item['subtotal']
                ]);

                $stockUpdate->execute([
                    'quantity'    => $item['quantity'],
                    'id'          => $item['product_id'],
                    'business_id' => $businessId
                ]);
            }

            // Handle Udhaar / Credit logic if not fully paid
            $unpaidAmount = 0.0;
            if ($paymentMethod === 'CREDIT' || in_array($paymentStatus, ['UNPAID', 'PARTIAL'], true)) {
                if ($paymentStatus === 'PARTIAL' && $amountPaid !== null) {
                    $unpaidAmount = max(0, round($netAmount - $amountPaid, 2));
                } else {
                    $unpaidAmount = $netAmount;
                }

                if ($unpaidAmount > 0 && $customerId) {
                    // 1. Insert udhaar entry
                    $stmtUdhaar = $pdo->prepare("
                        INSERT INTO udhaar_entries (business_id, customer_id, sale_id, type, amount, notes)
                        VALUES (:business_id, :customer_id, :sale_id, 'CREDIT', :amount, :notes)
                    ");
                    $stmtUdhaar->execute([
                        'business_id' => $businessId,
                        'customer_id' => $customerId,
                        'sale_id'     => $saleId,
                        'amount'      => $unpaidAmount,
                        'notes'       => "Credit sale invoice #{$invoiceNumber}"
                    ]);

                    // 2. Increase customer balance
                    $stmtCustBal = $pdo->prepare("
                        UPDATE customers
                        SET current_balance = current_balance + :amount
                        WHERE id = :id AND business_id = :business_id
                    ");
                    $stmtCustBal->execute([
                        'amount'      => $unpaidAmount,
                        'id'          => $customerId,
                        'business_id' => $businessId
                    ]);
                }
            }

            $pdo->commit();

            // Fetch complete response
            $saleResStmt = $pdo->prepare("
                SELECT s.*,
                       c.name AS customer_name, c.phone AS customer_phone, c.current_balance AS customer_current_balance,
                       b.name AS business_name, b.phone AS business_phone, b.currency, b.address AS business_address
                FROM sales s
                LEFT JOIN customers c ON s.customer_id = c.id
                INNER JOIN businesses b ON s.business_id = b.id
                WHERE s.id = :id
            ");
            $saleResStmt->execute(['id' => $saleId]);
            $createdSale = $saleResStmt->fetch(PDO::FETCH_ASSOC);
            $createdSale['items'] = $processedItems;

            jsonSuccess($createdSale, 'Sale created successfully and inventory updated', 201);
            break;

        default:
            jsonError('Method Not Allowed.', 405);
            break;
    }
} catch (InvalidArgumentException $e) {
    if ($pdo->inTransaction()) {
        $pdo->rollBack();
    }
    jsonError($e->getMessage(), 422);
} catch (Throwable $e) {
    if ($pdo->inTransaction()) {
        $pdo->rollBack();
    }
    jsonError('Server error: ' . $e->getMessage(), 500);
}
