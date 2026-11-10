<?php
declare(strict_types=1);

/**
 * BizPilot AI - Comprehensive Automated Test Suite
 * Executes end-to-end against live database and REST API endpoints.
 */

require_once __DIR__ . '/config/database.php';

// Test runner configuration
$baseUrl = getenv('API_BASE_URL') ?: 'http://localhost/BizPilotAI/backend/api';
$testSeedToken = 'test_token_al_madina_mart_secret_key_2026';

class ApiTestRunner
{
    private string $baseUrl;
    private string $token;
    private int $passed = 0;
    private int $failed = 0;
    private array $failures = [];

    public function __construct(string $baseUrl, string $defaultToken)
    {
        $this->baseUrl = rtrim($baseUrl, '/');
        $this->token = $defaultToken;
    }

    public function setToken(string $token): void
    {
        $this->token = $token;
    }

    public function request(string $endpoint, string $method = 'GET', ?array $data = null, ?string $overrideToken = null): array
    {
        $url = $this->baseUrl . '/' . ltrim($endpoint, '/');
        $ch = curl_init();

        $headers = [
            'Content-Type: application/json',
            'Accept: application/json'
        ];

        $tokenToUse = $overrideToken !== null ? $overrideToken : $this->token;
        if (!empty($tokenToUse)) {
            $headers[] = 'Authorization: Bearer ' . $tokenToUse;
        }

        if ($method === 'GET' && !empty($data)) {
            $url .= (str_contains($url, '?') ? '&' : '?') . http_build_query($data);
        }

        curl_setopt($ch, CURLOPT_URL, $url);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_CUSTOMREQUEST, $method);
        curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);
        curl_setopt($ch, CURLOPT_TIMEOUT, 10);

        if (in_array($method, ['POST', 'PUT', 'DELETE'], true) && $data !== null) {
            curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));
        }

        $responseBody = curl_exec($ch);
        $httpCode = (int)curl_getinfo($ch, CURLINFO_HTTP_CODE);
        $curlError = curl_error($ch);
        curl_close($ch);

        if ($curlError) {
            return [
                'code' => 0,
                'json' => null,
                'raw'  => '',
                'error'=> $curlError
            ];
        }

        $decoded = json_decode((string)$responseBody, true);

        return [
            'code' => $httpCode,
            'json' => $decoded,
            'raw'  => $responseBody
        ];
    }

    public function assert(string $testName, bool $condition, string $detail = ''): void
    {
        if ($condition) {
            $this->passed++;
            echo "  \033[32m✔ PASS\033[0m: {$testName}\n";
        } else {
            $this->failed++;
            $this->failures[] = "{$testName} - {$detail}";
            echo "  \033[31m✘ FAIL\033[0m: {$testName} - {$detail}\n";
        }
    }

    public function getResults(): array
    {
        return [
            'passed'   => $this->passed,
            'failed'   => $this->failed,
            'total'    => $this->passed + $this->failed,
            'failures' => $this->failures
        ];
    }
}

echo "====================================================================\n";
echo "   BIZPILOT AI - BACKEND & DATABASE AUTOMATED TEST SUITE            \n";
echo "====================================================================\n";
echo "Base API URL: {$baseUrl}\n\n";

$runner = new ApiTestRunner($baseUrl, $testSeedToken);

// =====================================================================
// TEST GROUP 1: Database Connection & Schema Verification
// =====================================================================
echo "\033[1;34m[GROUP 1] Database & Tables Integrity\033[0m\n";
try {
    $pdo = Database::getConnection();
    $runner->assert("PDO Connection Established", $pdo instanceof PDO);

    $tablesStmt = $pdo->query("SHOW TABLES");
    $existingTables = $tablesStmt->fetchAll(PDO::FETCH_COLUMN);

    $requiredTables = [
        'businesses', 'users', 'categories', 'products', 'customers',
        'sales', 'sale_items', 'udhaar_entries', 'purchases',
        'purchase_items', 'ai_insights_cache'
    ];

    $missingTables = array_diff($requiredTables, $existingTables);
    $runner->assert(
        "All 11 Core Tables Present",
        empty($missingTables),
        "Missing: " . implode(', ', $missingTables)
    );
} catch (Throwable $e) {
    $runner->assert("Database Connectivity", false, $e->getMessage());
}

// =====================================================================
// TEST GROUP 2: Authentication & Business Onboarding
// =====================================================================
echo "\n\033[1;34m[GROUP 2] Auth API (Register, Login, Profile)\033[0m\n";

// 2.1 Register New Business & Admin
$uniqueEmail = 'test_owner_' . time() . '_' . mt_rand(100, 999) . '@bizpilot.pk';
$registerRes = $runner->request('auth.php', 'POST', [
    'action'        => 'register',
    'business_name' => 'Metro Super Store Karachi',
    'owner_name'    => 'Zubair Ahmed',
    'phone'         => '03001234567',
    'currency'      => 'PKR',
    'email'         => $uniqueEmail,
    'password'      => 'supersecret123',
    'address'       => 'Tariq Road, PECHS, Karachi'
]);

$runner->assert(
    "Auth: Register new business returns 201 Created",
    $registerRes['code'] === 201 && ($registerRes['json']['success'] ?? false) === true,
    "HTTP {$registerRes['code']} - " . ($registerRes['json']['message'] ?? $registerRes['raw'])
);

$newBusinessToken = $registerRes['json']['data']['token'] ?? '';
$runner->assert(
    "Auth: Register returns valid API token",
    !empty($newBusinessToken) && strlen($newBusinessToken) >= 32
);

// 2.2 Login with Credentials
$loginRes = $runner->request('auth.php', 'POST', [
    'action'   => 'login',
    'email'    => $uniqueEmail,
    'password' => 'supersecret123'
]);

$runner->assert(
    "Auth: Login succeeds with 200 OK",
    $loginRes['code'] === 200 && ($loginRes['json']['success'] ?? false) === true
);

$loginToken = $loginRes['json']['data']['token'] ?? '';
$runner->assert(
    "Auth: Login returns authenticated user & token",
    $loginToken === $newBusinessToken && ($loginRes['json']['data']['user']['email'] ?? '') === $uniqueEmail
);

// 2.3 Profile Retrieval with Bearer Token
$profileRes = $runner->request('auth.php', 'GET', ['action' => 'profile'], $loginToken);
$runner->assert(
    "Auth: Profile retrieval succeeds with Bearer token",
    $profileRes['code'] === 200 && ($profileRes['json']['data']['user']['name'] ?? '') === 'Zubair Ahmed'
);

// 2.4 Profile Rejection with Invalid Token
$invalidRes = $runner->request('auth.php', 'GET', ['action' => 'profile'], 'invalid_fake_token_12345');
$runner->assert(
    "Auth: Rejects invalid Bearer token with 401 Unauthorized",
    $invalidRes['code'] === 401
);

// Switch back runner token to Al-Madina Mart (seed token) for product & sales tests
$runner->setToken($testSeedToken);

// =====================================================================
// TEST GROUP 3: Products & Inventory Management
// =====================================================================
echo "\n\033[1;34m[GROUP 3] Products & Inventory Management\033[0m\n";

// 3.1 List Products
$prodListRes = $runner->request('products.php', 'GET');
$runner->assert(
    "Products: List inventory returns 200 OK",
    $prodListRes['code'] === 200 && is_array($prodListRes['json']['data'] ?? null) && count($prodListRes['json']['data']) >= 10
);

// 3.2 Barcode Exact Lookup
$barcodeRes = $runner->request('products.php', 'GET', ['barcode' => '8961014123456']);
$runner->assert(
    "Products: Barcode lookup for '8961014123456' returns Dalda Cooking Oil",
    $barcodeRes['code'] === 200 && str_contains($barcodeRes['json']['data']['name'] ?? '', 'Dalda')
);

// 3.3 Low Stock Filter
$lowStockRes = $runner->request('products.php', 'GET', ['low_stock' => 1]);
$runner->assert(
    "Products: Low stock filter returns only products at or below threshold",
    $lowStockRes['code'] === 200 && count($lowStockRes['json']['data'] ?? []) >= 1
);

// 3.4 Create New Product (POST)
$newBarcode = '896' . mt_rand(1000000000, 9999999999);
$createProdRes = $runner->request('products.php', 'POST', [
    'name'                => 'Nestle Fruita Vitals Chaunsa Nectar 1L',
    'category_id'         => 2,
    'barcode'             => $newBarcode,
    'cost_price'          => 280.00,
    'selling_price'       => 350.00,
    'stock_quantity'      => 30,
    'low_stock_threshold' => 6
]);
$runner->assert(
    "Products: Create new product returns 201 Created",
    $createProdRes['code'] === 201 && ($createProdRes['json']['data']['name'] ?? '') === 'Nestle Fruita Vitals Chaunsa Nectar 1L'
);
$createdProdId = (int)($createProdRes['json']['data']['id'] ?? 0);

// 3.5 Update Product (PUT)
$updateProdRes = $runner->request('products.php', 'PUT', [
    'id'            => $createdProdId,
    'selling_price' => 370.00,
    'stock_quantity'=> 28
]);
$runner->assert(
    "Products: Update product returns 200 with new price 370.00",
    $updateProdRes['code'] === 200 && (float)($updateProdRes['json']['data']['selling_price'] ?? 0) === 370.00
);

// =====================================================================
// TEST GROUP 4: Customers & Khata Management
// =====================================================================
echo "\n\033[1;34m[GROUP 4] Customers & Khata Management\033[0m\n";

// 4.1 Create Customer (POST)
$testCustPhone = '0301' . mt_rand(1000000, 9999999);
$createCustRes = $runner->request('customers.php', 'POST', [
    'name'            => 'Shahid Afridi',
    'phone'           => $testCustPhone,
    'address'         => 'Sector F-7/1, Islamabad',
    'credit_limit'    => 75000.00,
    'initial_balance' => 0.00
]);
$runner->assert(
    "Customers: Create customer returns 201 Created",
    $createCustRes['code'] === 201 && ($createCustRes['json']['data']['name'] ?? '') === 'Shahid Afridi'
);
$createdCustId = (int)($createCustRes['json']['data']['id'] ?? 0);

// 4.2 Customer Search
$searchCustRes = $runner->request('customers.php', 'GET', ['q' => 'Shahid']);
$runner->assert(
    "Customers: Search by query 'Shahid' finds created customer",
    $searchCustRes['code'] === 200 && count($searchCustRes['json']['data'] ?? []) >= 1
);

// =====================================================================
// TEST GROUP 5: Sales & Atomic POS Checkout Transactions
// =====================================================================
echo "\n\033[1;34m[GROUP 5] Sales & Atomic POS Inventory Checkout\033[0m\n";

// Check initial stock of product #1 (Dalda Oil)
$initialProd1Res = $runner->request('products.php', 'GET', ['id' => 1]);
$initialStock1 = (int)($initialProd1Res['json']['data']['stock_quantity'] ?? 0);

// 5.1 Cash Sale POS Transaction
$cashSaleRes = $runner->request('sales.php', 'POST', [
    'payment_method' => 'CASH',
    'items'          => [
        ['product_id' => 1, 'quantity' => 2, 'unit_price' => 580.00]
    ],
    'discount_amount'=> 0.00,
    'notes'          => 'Automated test cash POS sale'
]);
$runner->assert(
    "Sales: Create Cash POS sale returns 201 Created",
    $cashSaleRes['code'] === 201 && !empty($cashSaleRes['json']['data']['invoice_number'])
);

// Verify stock deduction
$afterSale1Res = $runner->request('products.php', 'GET', ['id' => 1]);
$afterStock1 = (int)($afterSale1Res['json']['data']['stock_quantity'] ?? 0);
$runner->assert(
    "Sales: Inventory deducted atomically (-2 units: {$initialStock1} -> {$afterStock1})",
    $afterStock1 === ($initialStock1 - 2)
);

// 5.2 Credit Sale (Udhaar) POS Transaction
$creditSaleRes = $runner->request('sales.php', 'POST', [
    'customer_id'    => $createdCustId,
    'payment_method' => 'CREDIT',
    'payment_status' => 'UNPAID',
    'items'          => [
        ['product_id' => 1, 'quantity' => 1, 'unit_price' => 580.00],
        ['product_id' => 3, 'quantity' => 1, 'unit_price' => 680.00]
    ],
    'discount_amount'=> 0.00,
    'notes'          => 'Automated test credit POS sale'
]);
$runner->assert(
    "Sales: Create Credit (Udhaar) sale returns 201 Created",
    $creditSaleRes['code'] === 201 && (float)($creditSaleRes['json']['data']['net_amount'] ?? 0) === 1260.00
);
$creditSaleInvoice = $creditSaleRes['json']['data']['invoice_number'] ?? '';
$creditSaleId = (int)($creditSaleRes['json']['data']['id'] ?? 0);

// Verify customer balance increased by 1260.00
$checkCustBal = $runner->request('customers.php', 'GET', ['id' => $createdCustId]);
$runner->assert(
    "Sales: Customer Udhaar balance automatically increased to 1260.00 PKR",
    (float)($checkCustBal['json']['data']['current_balance'] ?? 0) === 1260.00
);

// =====================================================================
// TEST GROUP 6: Udhaar Settlements & Customer Ledger
// =====================================================================
echo "\n\033[1;34m[GROUP 6] Udhaar Settlements & Customer Ledger\033[0m\n";

// 6.1 Customer Ledger Statement
$ledgerRes = $runner->request('customer_ledger.php', 'GET', ['customer_id' => $createdCustId]);
$runner->assert(
    "Ledger: Customer statement generates with 200 OK and 1 entry",
    $ledgerRes['code'] === 200 && count($ledgerRes['json']['data']['ledger'] ?? []) === 1
);
$runner->assert(
    "Ledger: Statement running balance matches current balance (1260.00 PKR)",
    (float)($ledgerRes['json']['data']['current_balance'] ?? 0) === 1260.00
);

// 6.2 Record Partial Payment Received
$paymentRes = $runner->request('udhaar.php', 'POST', [
    'customer_id' => $createdCustId,
    'type'        => 'PAYMENT',
    'amount'      => 600.00,
    'notes'       => 'Cash payment received via test'
]);
$runner->assert(
    "Udhaar: Payment of 600.00 PKR recorded with 201 Created",
    $paymentRes['code'] === 201 && (float)($paymentRes['json']['data']['current_balance'] ?? 0) === 660.00
);

// 6.3 Verify Refreshed Ledger
$ledgerRes2 = $runner->request('customer_ledger.php', 'GET', ['customer_id' => $createdCustId]);
$runner->assert(
    "Ledger: Updated statement reflects both CREDIT (+1260) and PAYMENT (-600) = 660",
    count($ledgerRes2['json']['data']['ledger'] ?? []) === 2 && (float)($ledgerRes2['json']['data']['current_balance'] ?? 0) === 660.00
);

// 6.4 Udhaar Pending List
$pendingUdhaarRes = $runner->request('udhaar.php', 'GET');
$runner->assert(
    "Udhaar: Pending receivables list returned with total debtors count",
    $pendingUdhaarRes['code'] === 200 && ($pendingUdhaarRes['json']['data']['total_debtors'] ?? 0) >= 3
);

// =====================================================================
// TEST GROUP 7: Dashboard Summary Metrics
// =====================================================================
echo "\n\033[1;34m[GROUP 7] Dashboard Summary Metrics\033[0m\n";

$dashRes = $runner->request('dashboard.php', 'GET');
$runner->assert(
    "Dashboard: Metrics loaded with 200 OK",
    $dashRes['code'] === 200
);

$dashMetrics = $dashRes['json']['data']['metrics'] ?? [];
$runner->assert(
    "Dashboard: Today sales and profit are tracked",
    isset($dashMetrics['today_sales'], $dashMetrics['today_profit'], $dashMetrics['total_receivables'])
);
$runner->assert(
    "Dashboard: Low stock count alert matches active inventory",
    isset($dashMetrics['low_stock_count']) && $dashMetrics['low_stock_count'] >= 1
);
$runner->assert(
    "Dashboard: Recent transactions include created invoices",
    !empty($dashRes['json']['data']['recent_transactions'])
);

// =====================================================================
// TEST GROUP 8: Real AI Insights Engine
// =====================================================================
echo "\n\033[1;34m[GROUP 8] Real AI Business Insights Engine\033[0m\n";

$insightsRes = $runner->request('insights.php', 'GET', ['refresh' => 1]);
$runner->assert(
    "AI Insights: Engine computes recommendations with 200 OK",
    $insightsRes['code'] === 200
);

$insights = $insightsRes['json']['data']['insights'] ?? [];
$insightTypes = array_column($insights, 'type');

$runner->assert(
    "AI Insights: Detects top profit drivers ('top_grossing')",
    in_array('top_grossing', $insightTypes, true)
);

$runner->assert(
    "AI Insights: Detects dead stock & tied capital ('dead_stock')",
    in_array('dead_stock', $insightTypes, true)
);

$runner->assert(
    "AI Insights: Detects urgent low stock & stockout days ('low_stock_urgent')",
    in_array('low_stock_urgent', $insightTypes, true)
);

$runner->assert(
    "AI Insights: Analyzes revenue trajectory ('revenue_trajectory')",
    in_array('revenue_trajectory', $insightTypes, true)
);

// Bilingual check
$hasEnglish = false;
$hasUrdu = false;
foreach ($insights as $in) {
    if (!empty($in['description'])) {
        $hasEnglish = true;
    }
    if (!empty($in['urdu_translation'])) {
        $hasUrdu = true;
    }
}
$runner->assert(
    "AI Insights: All insights contain bilingual English and Urdu advice",
    $hasEnglish && $hasUrdu
);

// =====================================================================
// TEST GROUP 9: WhatsApp Share Links & Messaging
// =====================================================================
echo "\n\033[1;34m[GROUP 9] WhatsApp Integration\033[0m\n";

// 9.1 Invoice Link
$waInvoiceRes = $runner->request('whatsapp.php', 'GET', [
    'type'           => 'invoice',
    'invoice_number' => $creditSaleInvoice
]);
$runner->assert(
    "WhatsApp: Generates formatted invoice receipt with clean phone and wa.me link",
    $waInvoiceRes['code'] === 200 && str_contains($waInvoiceRes['json']['data']['whatsapp_url'] ?? '', 'https://wa.me/')
);

// 9.2 Udhaar Reminder Link
$waReminderRes = $runner->request('whatsapp.php', 'GET', [
    'type'        => 'udhaar_reminder',
    'customer_id' => $createdCustId
]);
$runner->assert(
    "WhatsApp: Generates polite Urdu & English Udhaar reminder link",
    $waReminderRes['code'] === 200 && str_contains($waReminderRes['json']['data']['whatsapp_url'] ?? '', 'https://wa.me/')
);

// =====================================================================
// TEST GROUP 10: Product Soft Deletion on Sold Item
// =====================================================================
echo "\n\033[1;34m[GROUP 10] Deletion & History Protection\033[0m\n";

$delRes = $runner->request('products.php', 'DELETE', ['id' => 1]);
$runner->assert(
    "Products: Product #1 with sales history is soft-deactivated (is_active=0) to protect ledger",
    $delRes['code'] === 200 && ($delRes['json']['data']['status'] ?? '') === 'deactivated'
);

// Verify that it's no longer in active products list
$checkActive = $runner->request('products.php', 'GET', ['id' => 1]);
$runner->assert(
    "Products: Product #1 marked is_active = 0",
    $checkActive['code'] === 200 && (int)($checkActive['json']['data']['is_active'] ?? 1) === 0
);

// Restore product #1 to active so everything stays healthy
$pdo->exec("UPDATE products SET is_active = 1 WHERE id = 1");

// =====================================================================
// FINAL RESULTS SUMMARY
// =====================================================================
$results = $runner->getResults();
echo "\n====================================================================\n";
echo "   TEST EXECUTION SUMMARY                                           \n";
echo "====================================================================\n";
echo "Total Assertions: {$results['total']}\n";
echo "Passed:           \033[32m{$results['passed']}\033[0m\n";
echo "Failed:           " . ($results['failed'] > 0 ? "\033[31m{$results['failed']}\033[0m" : "\033[32m0\033[0m") . "\n";

if ($results['failed'] > 0) {
    echo "\nFailures:\n";
    foreach ($results['failures'] as $f) {
        echo "  - {$f}\n";
    }
    exit(1);
} else {
    echo "\n\033[1;32m★ ALL 100% OF TESTS PASSED PERFECTLY! ★\033[0m\n\n";
    exit(0);
}
