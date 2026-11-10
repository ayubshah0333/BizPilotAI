<?php
declare(strict_types=1);

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../helpers/response.php';
require_once __DIR__ . '/../helpers/auth.php';

setupCors();

$pdo = Database::getConnection();
$user = authenticateUser($pdo);
$businessId = (int)$user['business_id'];

$data = getRequestData();
$customerId = !empty($data['customer_id']) ? (int)$data['customer_id'] : (!empty($data['id']) ? (int)$data['id'] : null);

if (!$customerId) {
    jsonError('Customer ID is required (e.g. ?customer_id=1).', 422);
}

try {
    // 1. Fetch customer
    $stmtCust = $pdo->prepare("
        SELECT id, name, phone, address, credit_limit, current_balance, created_at
        FROM customers
        WHERE id = :id AND business_id = :business_id
        LIMIT 1
    ");
    $stmtCust->execute(['id' => $customerId, 'business_id' => $businessId]);
    $customer = $stmtCust->fetch(PDO::FETCH_ASSOC);

    if (!$customer) {
        jsonError('Customer not found.', 404);
    }

    // 2. Fetch all udhaar entries in chronological order
    $stmtEntries = $pdo->prepare("
        SELECT u.id, u.sale_id, u.type, u.amount, u.notes, u.created_at,
               s.invoice_number, s.net_amount AS sale_net_amount, s.payment_method
        FROM udhaar_entries u
        LEFT JOIN sales s ON u.sale_id = s.id
        WHERE u.customer_id = :customer_id AND u.business_id = :business_id
        ORDER BY u.created_at ASC, u.id ASC
    ");
    $stmtEntries->execute(['customer_id' => $customerId, 'business_id' => $businessId]);
    $rawEntries = $stmtEntries->fetchAll(PDO::FETCH_ASSOC);

    $runningBalance = 0.0;
    $totalCredit = 0.0;
    $totalPaid = 0.0;
    $ledger = [];

    foreach ($rawEntries as $row) {
        $amount = (float)$row['amount'];
        $type = $row['type'];

        if ($type === 'CREDIT') {
            $runningBalance += $amount;
            $totalCredit += $amount;
        } else { // PAYMENT
            $runningBalance -= $amount;
            $totalPaid += $amount;
        }

        $ledger[] = [
            'id'              => (int)$row['id'],
            'date'            => $row['created_at'],
            'type'            => $type, // CREDIT or PAYMENT
            'amount'          => $amount,
            'running_balance' => round($runningBalance, 2),
            'sale_id'         => $row['sale_id'] ? (int)$row['sale_id'] : null,
            'invoice_number'  => $row['invoice_number'],
            'notes'           => $row['notes']
        ];
    }

    $summary = [
        'customer'             => $customer,
        'total_credit'         => round($totalCredit, 2),
        'total_paid'           => round($totalPaid, 2),
        'current_balance'      => round((float)$customer['current_balance'], 2),
        'calculated_balance'   => round($runningBalance, 2),
        'credit_limit'         => (float)$customer['credit_limit'],
        'available_credit'     => max(0, (float)$customer['credit_limit'] - (float)$customer['current_balance']),
        'total_transactions'   => count($ledger),
        'ledger'               => $ledger
    ];

    jsonSuccess($summary, 'Customer ledger statement generated successfully');

} catch (Throwable $e) {
    jsonError('Server error: ' . $e->getMessage(), 500);
}
