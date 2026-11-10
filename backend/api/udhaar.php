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
            // List pending udhaar balances
            $stmt = $pdo->prepare("
                SELECT c.id, c.name, c.phone, c.address, c.credit_limit, c.current_balance,
                       (SELECT MAX(created_at) FROM udhaar_entries WHERE customer_id = c.id) AS last_transaction_date
                FROM customers c
                WHERE c.business_id = :business_id AND c.current_balance > 0
                ORDER BY c.current_balance DESC
            ");
            $stmt->execute(['business_id' => $businessId]);
            $debtors = $stmt->fetchAll(PDO::FETCH_ASSOC);

            $totalReceivables = array_sum(array_column($debtors, 'current_balance'));

            jsonSuccess([
                'total_receivables' => round((float)$totalReceivables, 2),
                'total_debtors'     => count($debtors),
                'customers'         => $debtors
            ], 'Udhaar pending list retrieved');
            break;

        case 'POST':
            $customerId = !empty($data['customer_id']) ? (int)$data['customer_id'] : null;
            $type = strtoupper(trim((string)($data['type'] ?? 'PAYMENT')));
            $amount = isset($data['amount']) ? (float)$data['amount'] : 0.0;
            $notes = sanitizeString($data['notes'] ?? '');

            if (!$customerId) {
                jsonError('Customer ID is required.', 422);
            }

            if (!in_array($type, ['PAYMENT', 'CREDIT'], true)) {
                jsonError("Invalid type. Allowed values are 'PAYMENT' or 'CREDIT'.", 422);
            }

            if ($amount <= 0) {
                jsonError('Amount must be greater than 0.', 422);
            }

            // Verify customer belongs to business
            $checkStmt = $pdo->prepare("SELECT id, name, phone, current_balance, credit_limit FROM customers WHERE id = :id AND business_id = :business_id LIMIT 1");
            $checkStmt->execute(['id' => $customerId, 'business_id' => $businessId]);
            $customer = $checkStmt->fetch(PDO::FETCH_ASSOC);

            if (!$customer) {
                jsonError('Customer not found.', 404);
            }

            $pdo->beginTransaction();

            // Insert udhaar entry
            $insertStmt = $pdo->prepare("
                INSERT INTO udhaar_entries (business_id, customer_id, sale_id, type, amount, notes)
                VALUES (:business_id, :customer_id, NULL, :type, :amount, :notes)
            ");
            $insertStmt->execute([
                'business_id' => $businessId,
                'customer_id' => $customerId,
                'type'        => $type,
                'amount'      => $amount,
                'notes'       => !empty($notes) ? $notes : ($type === 'PAYMENT' ? 'Payment received' : 'Credit adjustment')
            ]);
            $entryId = (int)$pdo->lastInsertId();

            // Update customer balance
            if ($type === 'PAYMENT') {
                $updStmt = $pdo->prepare("UPDATE customers SET current_balance = current_balance - :amount WHERE id = :id");
            } else {
                $updStmt = $pdo->prepare("UPDATE customers SET current_balance = current_balance + :amount WHERE id = :id");
            }
            $updStmt->execute(['amount' => $amount, 'id' => $customerId]);

            $pdo->commit();

            // Fetch refreshed balance
            $fetchCust = $pdo->prepare("SELECT id, name, phone, current_balance FROM customers WHERE id = :id");
            $fetchCust->execute(['id' => $customerId]);
            $updatedCustomer = $fetchCust->fetch(PDO::FETCH_ASSOC);

            jsonSuccess([
                'entry_id'        => $entryId,
                'customer'        => $updatedCustomer,
                'type'            => $type,
                'amount'          => $amount,
                'current_balance' => (float)$updatedCustomer['current_balance']
            ], $type === 'PAYMENT' ? 'Payment recorded successfully' : 'Credit added successfully', 201);
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
