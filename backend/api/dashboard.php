<?php
declare(strict_types=1);

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../helpers/response.php';
require_once __DIR__ . '/../helpers/auth.php';

setupCors();

$pdo = Database::getConnection();
$user = authenticateUser($pdo);
$businessId = (int)$user['business_id'];

try {
    // 1. Today sales & profit
    $stmtToday = $pdo->prepare("
        SELECT COUNT(s.id) AS sales_count,
               COALESCE(SUM(s.net_amount), 0) AS total_revenue,
               COALESCE((
                   SELECT SUM((si.unit_price - si.cost_price) * si.quantity)
                   FROM sale_items si
                   INNER JOIN sales s2 ON si.sale_id = s2.id
                   WHERE s2.business_id = :biz_id1 AND DATE(s2.created_at) = CURDATE()
               ), 0) AS estimated_profit
        FROM sales s
        WHERE s.business_id = :biz_id2 AND DATE(s.created_at) = CURDATE()
    ");
    $stmtToday->execute(['biz_id1' => $businessId, 'biz_id2' => $businessId]);
    $today = $stmtToday->fetch(PDO::FETCH_ASSOC);

    // 2. Weekly sales (last 7 days)
    $stmtWeek = $pdo->prepare("
        SELECT COUNT(s.id) AS sales_count,
               COALESCE(SUM(s.net_amount), 0) AS total_revenue,
               COALESCE((
                   SELECT SUM((si.unit_price - si.cost_price) * si.quantity)
                   FROM sale_items si
                   INNER JOIN sales s2 ON si.sale_id = s2.id
                   WHERE s2.business_id = :biz_id1 AND s2.created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)
               ), 0) AS estimated_profit
        FROM sales s
        WHERE s.business_id = :biz_id2 AND s.created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)
    ");
    $stmtWeek->execute(['biz_id1' => $businessId, 'biz_id2' => $businessId]);
    $week = $stmtWeek->fetch(PDO::FETCH_ASSOC);

    // 3. Monthly sales (last 30 days)
    $stmtMonth = $pdo->prepare("
        SELECT COUNT(s.id) AS sales_count,
               COALESCE(SUM(s.net_amount), 0) AS total_revenue,
               COALESCE((
                   SELECT SUM((si.unit_price - si.cost_price) * si.quantity)
                   FROM sale_items si
                   INNER JOIN sales s2 ON si.sale_id = s2.id
                   WHERE s2.business_id = :biz_id1 AND s2.created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)
               ), 0) AS estimated_profit
        FROM sales s
        WHERE s.business_id = :biz_id2 AND s.created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)
    ");
    $stmtMonth->execute(['biz_id1' => $businessId, 'biz_id2' => $businessId]);
    $month = $stmtMonth->fetch(PDO::FETCH_ASSOC);

    // 4. Udhaar / Receivables
    $stmtUdhaar = $pdo->prepare("
        SELECT COALESCE(SUM(current_balance), 0) AS total_receivables,
               COUNT(*) AS debtors_count
        FROM customers
        WHERE business_id = :biz_id AND current_balance > 0
    ");
    $stmtUdhaar->execute(['biz_id' => $businessId]);
    $udhaar = $stmtUdhaar->fetch(PDO::FETCH_ASSOC);

    // 5. Low stock alerts count
    $stmtLowStock = $pdo->prepare("
        SELECT COUNT(*) AS low_stock_count
        FROM products
        WHERE business_id = :biz_id AND is_active = 1 AND stock_quantity <= low_stock_threshold
    ");
    $stmtLowStock->execute(['biz_id' => $businessId]);
    $lowStockCount = (int)$stmtLowStock->fetchColumn();

    // 6. Total active products count
    $stmtProdCount = $pdo->prepare("
        SELECT COUNT(*) AS total_products
        FROM products
        WHERE business_id = :biz_id AND is_active = 1
    ");
    $stmtProdCount->execute(['biz_id' => $businessId]);
    $totalProducts = (int)$stmtProdCount->fetchColumn();

    // 7. Recent 10 transactions
    $stmtRecent = $pdo->prepare("
        SELECT s.id, s.invoice_number, s.net_amount, s.payment_method, s.payment_status, s.created_at,
               COALESCE(c.name, 'Walk-in Customer') AS customer_name,
               (SELECT COUNT(*) FROM sale_items WHERE sale_id = s.id) AS items_count
        FROM sales s
        LEFT JOIN customers c ON s.customer_id = c.id
        WHERE s.business_id = :biz_id
        ORDER BY s.id DESC
        LIMIT 10
    ");
    $stmtRecent->execute(['biz_id' => $businessId]);
    $recentSales = $stmtRecent->fetchAll(PDO::FETCH_ASSOC);

    // 8. Daily sales trend (last 7 days for charts)
    $stmtDailyTrend = $pdo->prepare("
        SELECT DATE(created_at) AS sale_date,
               COUNT(*) AS order_count,
               COALESCE(SUM(net_amount), 0) AS daily_revenue
        FROM sales
        WHERE business_id = :biz_id AND created_at >= DATE_SUB(CURDATE(), INTERVAL 6 DAY)
        GROUP BY DATE(created_at)
        ORDER BY sale_date ASC
    ");
    $stmtDailyTrend->execute(['biz_id' => $businessId]);
    $dailyTrend = $stmtDailyTrend->fetchAll(PDO::FETCH_ASSOC);

    $dashboardData = [
        'currency' => $user['currency'],
        'metrics'  => [
            'today_sales'          => round((float)$today['total_revenue'], 2),
            'today_orders'         => (int)$today['sales_count'],
            'today_profit'         => round((float)$today['estimated_profit'], 2),
            'weekly_sales'         => round((float)$week['total_revenue'], 2),
            'weekly_orders'        => (int)$week['sales_count'],
            'weekly_profit'        => round((float)$week['estimated_profit'], 2),
            'monthly_sales'        => round((float)$month['total_revenue'], 2),
            'monthly_orders'       => (int)$month['sales_count'],
            'monthly_profit'       => round((float)$month['estimated_profit'], 2),
            'total_receivables'    => round((float)$udhaar['total_receivables'], 2),
            'debtors_count'        => (int)$udhaar['debtors_count'],
            'low_stock_count'      => $lowStockCount,
            'total_products_count' => $totalProducts
        ],
        'recent_transactions' => $recentSales,
        'daily_trend'         => $dailyTrend
    ];

    jsonSuccess($dashboardData, 'Dashboard summary metrics loaded successfully');
} catch (Throwable $e) {
    jsonError('Server error: ' . $e->getMessage(), 500);
}
