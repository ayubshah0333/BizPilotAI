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
            // 1. Single product by ID
            if (!empty($data['id'])) {
                $stmt = $pdo->prepare("
                    SELECT p.*, c.name AS category_name, c.icon AS category_icon
                    FROM products p
                    LEFT JOIN categories c ON p.category_id = c.id
                    WHERE p.id = :id AND p.business_id = :business_id
                    LIMIT 1
                ");
                $stmt->execute(['id' => (int)$data['id'], 'business_id' => $businessId]);
                $product = $stmt->fetch(PDO::FETCH_ASSOC);

                if (!$product) {
                    jsonError('Product not found.', 404);
                }
                jsonSuccess($product, 'Product retrieved successfully');
            }

            // 2. Barcode exact lookup
            if (!empty($data['barcode'])) {
                $stmt = $pdo->prepare("
                    SELECT p.*, c.name AS category_name, c.icon AS category_icon
                    FROM products p
                    LEFT JOIN categories c ON p.category_id = c.id
                    WHERE p.barcode = :barcode AND p.business_id = :business_id AND p.is_active = 1
                    LIMIT 1
                ");
                $stmt->execute(['barcode' => trim((string)$data['barcode']), 'business_id' => $businessId]);
                $product = $stmt->fetch(PDO::FETCH_ASSOC);

                if (!$product) {
                    jsonError('Product with this barcode not found.', 404);
                }
                jsonSuccess($product, 'Product found by barcode');
            }

            // 3. Search and filtered list
            $sql = "
                SELECT p.*, c.name AS category_name, c.icon AS category_icon,
                       CASE WHEN p.stock_quantity <= p.low_stock_threshold THEN 1 ELSE 0 END AS is_low_stock
                FROM products p
                LEFT JOIN categories c ON p.category_id = c.id
                WHERE p.business_id = :business_id
            ";
            $params = ['business_id' => $businessId];

            if (isset($data['is_active'])) {
                $sql .= " AND p.is_active = :is_active";
                $params['is_active'] = (int)$data['is_active'];
            } else {
                $sql .= " AND p.is_active = 1";
            }

            if (!empty($data['category_id'])) {
                $sql .= " AND p.category_id = :category_id";
                $params['category_id'] = (int)$data['category_id'];
            }

            if (!empty($data['low_stock']) && (int)$data['low_stock'] === 1) {
                $sql .= " AND p.stock_quantity <= p.low_stock_threshold";
            }

            if (!empty($data['q'])) {
                $sql .= " AND (p.name LIKE :search1 OR p.barcode LIKE :search2 OR p.sku LIKE :search3)";
                $term = '%' . trim((string)$data['q']) . '%';
                $params['search1'] = $term;
                $params['search2'] = $term;
                $params['search3'] = $term;
            }

            $sql .= " ORDER BY p.id DESC";

            $stmt = $pdo->prepare($sql);
            $stmt->execute($params);
            $products = $stmt->fetchAll(PDO::FETCH_ASSOC);

            jsonSuccess($products, 'Products retrieved successfully');
            break;

        case 'POST':
            $name = sanitizeString($data['name'] ?? '');
            if (empty($name)) {
                jsonError('Product name is required.', 422);
            }

            $categoryId = !empty($data['category_id']) ? (int)$data['category_id'] : null;
            $costPrice = isset($data['cost_price']) ? max(0, (float)$data['cost_price']) : 0.0;
            $sellingPrice = isset($data['selling_price']) ? max(0, (float)$data['selling_price']) : 0.0;
            $stockQuantity = isset($data['stock_quantity']) ? (int)$data['stock_quantity'] : 0;
            $lowStockThreshold = isset($data['low_stock_threshold']) ? (int)$data['low_stock_threshold'] : 5;
            $sku = sanitizeString($data['sku'] ?? '');
            if (empty($sku)) {
                $sku = 'SKU-' . strtoupper(substr(md5(uniqid((string)mt_rand(), true)), 0, 8));
            }
            $barcode = sanitizeString($data['barcode'] ?? '');
            $isActive = isset($data['is_active']) ? (int)$data['is_active'] : 1;

            // Check if barcode already exists in this business
            if (!empty($barcode)) {
                $checkStmt = $pdo->prepare("SELECT id FROM products WHERE business_id = :biz_id AND barcode = :barcode LIMIT 1");
                $checkStmt->execute(['biz_id' => $businessId, 'barcode' => $barcode]);
                if ($checkStmt->fetch()) {
                    jsonError('A product with this barcode already exists in your inventory.', 409);
                }
            }

            $stmt = $pdo->prepare("
                INSERT INTO products (business_id, category_id, name, sku, barcode, cost_price, selling_price, stock_quantity, low_stock_threshold, is_active)
                VALUES (:business_id, :category_id, :name, :sku, :barcode, :cost_price, :selling_price, :stock_quantity, :low_stock_threshold, :is_active)
            ");
            $stmt->execute([
                'business_id'         => $businessId,
                'category_id'         => $categoryId,
                'name'                => $name,
                'sku'                 => $sku,
                'barcode'             => !empty($barcode) ? $barcode : null,
                'cost_price'          => $costPrice,
                'selling_price'       => $sellingPrice,
                'stock_quantity'      => $stockQuantity,
                'low_stock_threshold' => $lowStockThreshold,
                'is_active'           => $isActive
            ]);
            $newId = (int)$pdo->lastInsertId();

            $fetchStmt = $pdo->prepare("
                SELECT p.*, c.name AS category_name, c.icon AS category_icon
                FROM products p
                LEFT JOIN categories c ON p.category_id = c.id
                WHERE p.id = :id
            ");
            $fetchStmt->execute(['id' => $newId]);
            $created = $fetchStmt->fetch(PDO::FETCH_ASSOC);

            jsonSuccess($created, 'Product created successfully', 201);
            break;

        case 'PUT':
            $productId = !empty($data['id']) ? (int)$data['id'] : null;
            if (!$productId) {
                jsonError('Product ID is required for update.', 422);
            }

            // Verify ownership
            $checkStmt = $pdo->prepare("SELECT id FROM products WHERE id = :id AND business_id = :business_id LIMIT 1");
            $checkStmt->execute(['id' => $productId, 'business_id' => $businessId]);
            if (!$checkStmt->fetch()) {
                jsonError('Product not found or access denied.', 404);
            }

            $fields = [];
            $params = ['id' => $productId, 'business_id' => $businessId];

            if (isset($data['name'])) {
                $fields[] = 'name = :name';
                $params['name'] = sanitizeString($data['name']);
            }
            if (array_key_exists('category_id', $data)) {
                $fields[] = 'category_id = :category_id';
                $params['category_id'] = !empty($data['category_id']) ? (int)$data['category_id'] : null;
            }
            if (isset($data['sku'])) {
                $fields[] = 'sku = :sku';
                $params['sku'] = sanitizeString($data['sku']);
            }
            if (array_key_exists('barcode', $data)) {
                $fields[] = 'barcode = :barcode';
                $params['barcode'] = !empty($data['barcode']) ? sanitizeString($data['barcode']) : null;
            }
            if (isset($data['cost_price'])) {
                $fields[] = 'cost_price = :cost_price';
                $params['cost_price'] = max(0, (float)$data['cost_price']);
            }
            if (isset($data['selling_price'])) {
                $fields[] = 'selling_price = :selling_price';
                $params['selling_price'] = max(0, (float)$data['selling_price']);
            }
            if (isset($data['stock_quantity'])) {
                $fields[] = 'stock_quantity = :stock_quantity';
                $params['stock_quantity'] = (int)$data['stock_quantity'];
            }
            if (isset($data['low_stock_threshold'])) {
                $fields[] = 'low_stock_threshold = :low_stock_threshold';
                $params['low_stock_threshold'] = (int)$data['low_stock_threshold'];
            }
            if (isset($data['is_active'])) {
                $fields[] = 'is_active = :is_active';
                $params['is_active'] = (int)$data['is_active'];
            }

            if (empty($fields)) {
                jsonError('No fields provided to update.', 422);
            }

            $updateSql = "UPDATE products SET " . implode(', ', $fields) . " WHERE id = :id AND business_id = :business_id";
            $updStmt = $pdo->prepare($updateSql);
            $updStmt->execute($params);

            $fetchStmt = $pdo->prepare("
                SELECT p.*, c.name AS category_name, c.icon AS category_icon
                FROM products p
                LEFT JOIN categories c ON p.category_id = c.id
                WHERE p.id = :id
            ");
            $fetchStmt->execute(['id' => $productId]);
            $updated = $fetchStmt->fetch(PDO::FETCH_ASSOC);

            jsonSuccess($updated, 'Product updated successfully');
            break;

        case 'DELETE':
            $productId = !empty($data['id']) ? (int)$data['id'] : null;
            if (!$productId) {
                jsonError('Product ID is required for deletion.', 422);
            }

            // Verify existence
            $checkStmt = $pdo->prepare("SELECT id FROM products WHERE id = :id AND business_id = :business_id LIMIT 1");
            $checkStmt->execute(['id' => $productId, 'business_id' => $businessId]);
            if (!$checkStmt->fetch()) {
                jsonError('Product not found.', 404);
            }

            // Check if product has sales or purchase history
            $salesCountStmt = $pdo->prepare("SELECT COUNT(*) FROM sale_items WHERE product_id = :id");
            $salesCountStmt->execute(['id' => $productId]);
            $salesCount = (int)$salesCountStmt->fetchColumn();

            if ($salesCount > 0) {
                // Soft delete to protect financial history
                $softDel = $pdo->prepare("UPDATE products SET is_active = 0 WHERE id = :id AND business_id = :business_id");
                $softDel->execute(['id' => $productId, 'business_id' => $businessId]);
                jsonSuccess(['id' => $productId, 'status' => 'deactivated'], 'Product has existing sales records, so it was deactivated (soft-deleted).');
            } else {
                $hardDel = $pdo->prepare("DELETE FROM products WHERE id = :id AND business_id = :business_id");
                $hardDel->execute(['id' => $productId, 'business_id' => $businessId]);
                jsonSuccess(['id' => $productId, 'status' => 'deleted'], 'Product permanently deleted.');
            }
            break;

        default:
            jsonError('Method Not Allowed.', 405);
            break;
    }
} catch (Throwable $e) {
    jsonError('Server error: ' . $e->getMessage(), 500);
}
