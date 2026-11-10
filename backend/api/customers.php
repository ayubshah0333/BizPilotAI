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
            // 1. Single customer by ID
            if (!empty($data['id'])) {
                $stmt = $pdo->prepare("
                    SELECT c.*,
                           (SELECT COUNT(*) FROM sales WHERE customer_id = c.id) AS total_orders,
                           (SELECT COALESCE(SUM(net_amount), 0) FROM sales WHERE customer_id = c.id) AS total_spent
                    FROM customers c
                    WHERE c.id = :id AND c.business_id = :business_id
                    LIMIT 1
                ");
                $stmt->execute(['id' => (int)$data['id'], 'business_id' => $businessId]);
                $customer = $stmt->fetch(PDO::FETCH_ASSOC);

                if (!$customer) {
                    jsonError('Customer not found.', 404);
                }
                jsonSuccess($customer, 'Customer details retrieved');
            }

            // 2. Filter / search list
            $sql = "
                SELECT c.*,
                       (SELECT COUNT(*) FROM sales WHERE customer_id = c.id) AS total_orders,
                       (SELECT COALESCE(SUM(net_amount), 0) FROM sales WHERE customer_id = c.id) AS total_spent
                FROM customers c
                WHERE c.business_id = :business_id
            ";
            $params = ['business_id' => $businessId];

            if (!empty($data['has_udhaar']) && (int)$data['has_udhaar'] === 1) {
                $sql .= " AND c.current_balance > 0";
            }

            if (!empty($data['q'])) {
                $sql .= " AND (c.name LIKE :q1 OR c.phone LIKE :q2)";
                $queryTerm = '%' . trim((string)$data['q']) . '%';
                $params['q1'] = $queryTerm;
                $params['q2'] = $queryTerm;
            }

            $sql .= " ORDER BY c.current_balance DESC, c.name ASC";

            $stmt = $pdo->prepare($sql);
            $stmt->execute($params);
            $customers = $stmt->fetchAll(PDO::FETCH_ASSOC);

            jsonSuccess($customers, 'Customers retrieved successfully');
            break;

        case 'POST':
            $name = sanitizeString($data['name'] ?? '');
            if (empty($name)) {
                jsonError('Customer name is required.', 422);
            }

            $phone = sanitizeString($data['phone'] ?? '');
            $address = sanitizeString($data['address'] ?? '');
            $creditLimit = isset($data['credit_limit']) ? max(0, (float)$data['credit_limit']) : 50000.0;
            $initialBalance = isset($data['initial_balance']) ? (float)$data['initial_balance'] : 0.0;

            $pdo->beginTransaction();

            $stmt = $pdo->prepare("
                INSERT INTO customers (business_id, name, phone, address, credit_limit, current_balance)
                VALUES (:business_id, :name, :phone, :address, :credit_limit, :current_balance)
            ");
            $stmt->execute([
                'business_id'     => $businessId,
                'name'            => $name,
                'phone'           => !empty($phone) ? $phone : null,
                'address'         => !empty($address) ? $address : null,
                'credit_limit'    => $creditLimit,
                'current_balance' => $initialBalance
            ]);
            $customerId = (int)$pdo->lastInsertId();

            if ($initialBalance > 0) {
                $stmtUdhaar = $pdo->prepare("
                    INSERT INTO udhaar_entries (business_id, customer_id, sale_id, type, amount, notes)
                    VALUES (:business_id, :customer_id, NULL, 'CREDIT', :amount, :notes)
                ");
                $stmtUdhaar->execute([
                    'business_id' => $businessId,
                    'customer_id' => $customerId,
                    'amount'      => $initialBalance,
                    'notes'       => 'Opening / previous balance brought forward'
                ]);
            }

            $pdo->commit();

            $fetchStmt = $pdo->prepare("SELECT * FROM customers WHERE id = :id");
            $fetchStmt->execute(['id' => $customerId]);
            $customer = $fetchStmt->fetch(PDO::FETCH_ASSOC);

            jsonSuccess($customer, 'Customer created successfully', 201);
            break;

        case 'PUT':
            $customerId = !empty($data['id']) ? (int)$data['id'] : null;
            if (!$customerId) {
                jsonError('Customer ID is required.', 422);
            }

            // Verify existence
            $checkStmt = $pdo->prepare("SELECT id FROM customers WHERE id = :id AND business_id = :business_id LIMIT 1");
            $checkStmt->execute(['id' => $customerId, 'business_id' => $businessId]);
            if (!$checkStmt->fetch()) {
                jsonError('Customer not found.', 404);
            }

            $fields = [];
            $params = ['id' => $customerId, 'business_id' => $businessId];

            if (isset($data['name'])) {
                $fields[] = 'name = :name';
                $params['name'] = sanitizeString($data['name']);
            }
            if (array_key_exists('phone', $data)) {
                $fields[] = 'phone = :phone';
                $params['phone'] = !empty($data['phone']) ? sanitizeString($data['phone']) : null;
            }
            if (array_key_exists('address', $data)) {
                $fields[] = 'address = :address';
                $params['address'] = !empty($data['address']) ? sanitizeString($data['address']) : null;
            }
            if (isset($data['credit_limit'])) {
                $fields[] = 'credit_limit = :credit_limit';
                $params['credit_limit'] = max(0, (float)$data['credit_limit']);
            }

            if (empty($fields)) {
                jsonError('No fields provided to update.', 422);
            }

            $sql = "UPDATE customers SET " . implode(', ', $fields) . " WHERE id = :id AND business_id = :business_id";
            $upd = $pdo->prepare($sql);
            $upd->execute($params);

            $fetchStmt = $pdo->prepare("SELECT * FROM customers WHERE id = :id");
            $fetchStmt->execute(['id' => $customerId]);
            $updated = $fetchStmt->fetch(PDO::FETCH_ASSOC);

            jsonSuccess($updated, 'Customer updated successfully');
            break;

        default:
            jsonError('Method Not Allowed.', 405);
            break;
    }
} catch (Throwable $e) {
    if ($pdo->inTransaction()) {
        $pdo->rollBack();
    }
    jsonError('Server error: ' . $e->getMessage(), 500);
}
