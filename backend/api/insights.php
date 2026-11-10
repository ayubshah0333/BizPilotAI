<?php
declare(strict_types=1);

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../helpers/response.php';
require_once __DIR__ . '/../helpers/auth.php';

setupCors();

$pdo = Database::getConnection();
$user = authenticateUser($pdo);
$businessId = (int)$user['business_id'];
$currency = $user['currency'] ?? 'PKR';

$data = getRequestData();
$forceRefresh = !empty($data['refresh']);

try {
    // If not forcing refresh, check if we have recent insights generated in the last 15 minutes
    if (!$forceRefresh) {
        $recentCacheStmt = $pdo->prepare("
            SELECT * FROM ai_insights_cache
            WHERE business_id = :biz_id AND created_at >= DATE_SUB(NOW(), INTERVAL 15 MINUTE)
            ORDER BY FIELD(severity, 'high', 'medium', 'info'), id DESC
        ");
        $recentCacheStmt->execute(['biz_id' => $businessId]);
        $cachedInsights = $recentCacheStmt->fetchAll(PDO::FETCH_ASSOC);

        if (!empty($cachedInsights)) {
            jsonSuccess([
                'source'   => 'cache',
                'insights' => $cachedInsights
            ], 'AI insights retrieved from active cache');
        }
    }

    // =========================================================================
    // REAL AI ANALYTICAL ENGINE COMPUTATION
    // =========================================================================

    $generatedInsights = [];

    // 1. TOP 5 PROFIT GENERATORS (Last 30 Days)
    $stmtTopProfit = $pdo->prepare("
        SELECT p.id, p.name, p.cost_price, p.selling_price, p.stock_quantity,
               COALESCE(SUM(si.quantity), 0) AS total_units_sold,
               COALESCE(SUM(si.subtotal), 0) AS total_revenue,
               COALESCE(SUM((si.unit_price - si.cost_price) * si.quantity), 0) AS total_profit
        FROM products p
        LEFT JOIN sale_items si ON p.id = si.product_id
        LEFT JOIN sales s ON si.sale_id = s.id AND s.created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)
        WHERE p.business_id = :biz_id AND p.is_active = 1
        GROUP BY p.id, p.name, p.cost_price, p.selling_price, p.stock_quantity
        HAVING total_profit > 0
        ORDER BY total_profit DESC
        LIMIT 5
    ");
    $stmtTopProfit->execute(['biz_id' => $businessId]);
    $topProfitProducts = $stmtTopProfit->fetchAll(PDO::FETCH_ASSOC);

    if (!empty($topProfitProducts)) {
        $leadProduct = $topProfitProducts[0];
        $marginPct = $leadProduct['total_revenue'] > 0
            ? round(($leadProduct['total_profit'] / $leadProduct['total_revenue']) * 100, 1)
            : 0;

        $profitTitle = "Star Performer: " . $leadProduct['name'];
        $profitEn = sprintf(
            "Product '%s' is your highest profit driver, generating %s %s gross profit (%s%% margin) over the past 30 days. Maintain buffer stock to prevent lost revenue.",
            $leadProduct['name'],
            number_format((float)$leadProduct['total_profit'], 2),
            $currency,
            $marginPct
        );
        $profitUr = sprintf(
            "پراڈکٹ '%s' آپ کا سب سے زیادہ منافع دینے والا آئٹم ہے جس نے گزشتہ 30 دنوں میں %s %s خالص منافع کمایا (%s%% مارجن)۔ سیلز جاری رکھنے کے لیے اس کا وافر اسٹاک رکھیں۔",
            $leadProduct['name'],
            number_format((float)$leadProduct['total_profit'], 2),
            $currency,
            $marginPct
        );

        $generatedInsights[] = [
            'type'             => 'top_grossing',
            'severity'         => 'info',
            'title'            => $profitTitle,
            'description'      => $profitEn,
            'urdu_translation' => $profitUr,
            'metadata'         => $topProfitProducts
        ];
    }

    // 2. DEAD STOCK & TIED-UP CAPITAL DETECTION
    // Products with stock > 0, active = 1, but 0 sales in the last 30 days
    $stmtDeadStock = $pdo->prepare("
        SELECT p.id, p.name, p.cost_price, p.selling_price, p.stock_quantity,
               (p.cost_price * p.stock_quantity) AS tied_capital
        FROM products p
        WHERE p.business_id = :biz_id AND p.is_active = 1 AND p.stock_quantity > 0
          AND p.id NOT IN (
              SELECT DISTINCT si.product_id
              FROM sale_items si
              INNER JOIN sales s ON si.sale_id = s.id
              WHERE s.business_id = :biz_id2 AND s.created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)
          )
        ORDER BY tied_capital DESC
        LIMIT 10
    ");
    $stmtDeadStock->execute(['biz_id' => $businessId, 'biz_id2' => $businessId]);
    $deadStockItems = $stmtDeadStock->fetchAll(PDO::FETCH_ASSOC);

    if (!empty($deadStockItems)) {
        $deadCount = count($deadStockItems);
        $totalTiedCapital = array_sum(array_column($deadStockItems, 'tied_capital'));
        $topDeadNames = array_slice(array_column($deadStockItems, 'name'), 0, 3);

        $deadTitle = "Capital Alert: {$deadCount} Slow-Moving/Dead Stock Items";
        $deadEn = sprintf(
            "%d inventory items have recorded zero sales in the last 30 days, locking up %s %s in non-liquid working capital (e.g. %s). Recommendation: Run a weekend bundle promotion or 10-15%% clearance discount to recover cash.",
            $deadCount,
            number_format((float)$totalTiedCapital, 2),
            $currency,
            implode(', ', $topDeadNames)
        );
        $deadUr = sprintf(
            "آپ کی %d پراڈکٹس پچھلے 30 دنوں سے بالکل نہیں بکیں، جس سے %s %s کی رقم بلاک ہو چکی ہے (مثلاً %s)۔ مشورہ: کیش فلو بحال کرنے کے لیے بنڈل آفر یا 10-15%% ڈسکاؤنٹ پر کلیئرنس کریں۔",
            $deadCount,
            number_format((float)$totalTiedCapital, 2),
            $currency,
            implode(', ', $topDeadNames)
        );

        $generatedInsights[] = [
            'type'             => 'dead_stock',
            'severity'         => 'medium',
            'title'            => $deadTitle,
            'description'      => $deadEn,
            'urdu_translation' => $deadUr,
            'metadata'         => $deadStockItems
        ];
    }

    // 3. LOW-STOCK URGENCY & DEPLETION VELOCITY
    // Check products where stock <= threshold and calculate sales velocity (units/day in last 14 days)
    $stmtLowStock = $pdo->prepare("
        SELECT p.id, p.name, p.stock_quantity, p.low_stock_threshold,
               COALESCE((
                   SELECT SUM(si.quantity)
                   FROM sale_items si
                   INNER JOIN sales s ON si.sale_id = s.id
                   WHERE si.product_id = p.id AND s.created_at >= DATE_SUB(NOW(), INTERVAL 14 DAY)
               ), 0) AS units_sold_14d
        FROM products p
        WHERE p.business_id = :biz_id AND p.is_active = 1 AND p.stock_quantity <= p.low_stock_threshold
        ORDER BY p.stock_quantity ASC
    ");
    $stmtLowStock->execute(['biz_id' => $businessId]);
    $lowStockProducts = $stmtLowStock->fetchAll(PDO::FETCH_ASSOC);

    if (!empty($lowStockProducts)) {
        $urgentItems = [];
        foreach ($lowStockProducts as $lp) {
            $dailyVelocity = max(0.1, (float)$lp['units_sold_14d'] / 14);
            $daysRemaining = max(0, round((int)$lp['stock_quantity'] / $dailyVelocity, 1));
            $urgentItems[] = [
                'name'           => $lp['name'],
                'stock'          => (int)$lp['stock_quantity'],
                'days_remaining' => $daysRemaining
            ];
        }

        $urgentCount = count($urgentItems);
        $mostCritical = $urgentItems[0];

        $stockTitle = "Stockout Emergency: {$urgentCount} Critical Items";
        $stockEn = sprintf(
            "%d items are below minimum safety threshold. Most critical is '%s' with only %d units remaining (~%s days of stock left). Place reorder with supplier immediately.",
            $urgentCount,
            $mostCritical['name'],
            $mostCritical['stock'],
            $mostCritical['days_remaining']
        );
        $stockUr = sprintf(
            "%d پراڈکٹس کا اسٹاک خطرناک حد تک کم ہو چکا ہے۔ سب سے نازک صورتحال '%s' کی ہے جس کے صرف %d پیس باقی ہیں (تقریباً %s دن کا سامان)۔ سپلائر کو فوراً آرڈر دیں۔",
            $urgentCount,
            $mostCritical['name'],
            $mostCritical['stock'],
            $mostCritical['days_remaining']
        );

        $generatedInsights[] = [
            'type'             => 'low_stock_urgent',
            'severity'         => 'high',
            'title'            => $stockTitle,
            'description'      => $stockEn,
            'urdu_translation' => $stockUr,
            'metadata'         => $urgentItems
        ];
    }

    // 4. REVENUE TRAJECTORY (Week-over-Week Momentum)
    $stmtThisWeek = $pdo->prepare("
        SELECT COALESCE(SUM(net_amount), 0) FROM sales
        WHERE business_id = :biz_id AND created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)
    ");
    $stmtThisWeek->execute(['biz_id' => $businessId]);
    $revThisWeek = (float)$stmtThisWeek->fetchColumn();

    $stmtLastWeek = $pdo->prepare("
        SELECT COALESCE(SUM(net_amount), 0) FROM sales
        WHERE business_id = :biz_id AND created_at >= DATE_SUB(NOW(), INTERVAL 14 DAY)
          AND created_at < DATE_SUB(NOW(), INTERVAL 7 DAY)
    ");
    $stmtLastWeek->execute(['biz_id' => $businessId]);
    $revLastWeek = (float)$stmtLastWeek->fetchColumn();

    $trajectorySeverity = 'info';
    if ($revLastWeek > 0) {
        $growthPct = round((($revThisWeek - $revLastWeek) / $revLastWeek) * 100, 1);
        if ($growthPct >= 10) {
            $trajTitle = "Revenue Trajectory: Upward Momentum (+{$growthPct}%)";
            $trajEn = "Weekly sales surged to " . number_format($revThisWeek, 2) . " {$currency} compared to " . number_format($revLastWeek, 2) . " {$currency} last week (+{$growthPct}%). Customer demand is robust.";
            $trajUr = "ہفتہ وار سیلز " . number_format($revThisWeek, 2) . " {$currency} تک پہنچ گئی ہے جو پچھلے ہفتے کے مقابلے میں {$growthPct}% زیادہ ہے۔ گاہکوں کا رجحان بہترین ہے۔";
            $trajectorySeverity = 'info';
        } elseif ($growthPct <= -10) {
            $trajTitle = "Revenue Dip Warning: Declining Trajectory ({$growthPct}%)";
            $trajEn = "Sales dropped by " . abs($growthPct) . "% this week compared to last week (" . number_format($revThisWeek, 2) . " vs " . number_format($revLastWeek, 2) . " {$currency}). Review foot traffic, popular stock availability, and promotional activity.";
            $trajUr = "سیلز میں پچھلے ہفتے کی نسبت " . abs($growthPct) . "% کمی دیکھی گئی ہے (" . number_format($revThisWeek, 2) . " بمقابلہ " . number_format($revLastWeek, 2) . " {$currency})۔ مال کی دستیابی اور گاہکوں کی سرگرمی کا جائزہ لیں۔";
            $trajectorySeverity = 'medium';
        } else {
            $trajTitle = "Revenue Trajectory: Stable";
            $trajEn = "Sales have held steady at " . number_format($revThisWeek, 2) . " {$currency} over the past 7 days.";
            $trajUr = "سیلز پچھلے 7 دنوں میں " . number_format($revThisWeek, 2) . " {$currency} کے ساتھ متوازن اور مستحکم رہی ہے۔";
            $trajectorySeverity = 'info';
        }
    } else {
        $trajTitle = "Revenue Trajectory: Initial Growth Phase";
        $trajEn = "Generated " . number_format($revThisWeek, 2) . " {$currency} in sales over the last 7 days.";
        $trajUr = "پچھلے 7 دنوں میں " . number_format($revThisWeek, 2) . " {$currency} کی سیلز ریکارڈ کی گئیں۔";
    }

    $generatedInsights[] = [
        'type'             => 'revenue_trajectory',
        'severity'         => $trajectorySeverity,
        'title'            => $trajTitle,
        'description'      => $trajEn,
        'urdu_translation' => $trajUr,
        'metadata'         => [
            'this_week_revenue' => $revThisWeek,
            'last_week_revenue' => $revLastWeek
        ]
    ];

    // 5. UDHAAR / CASH FLOW EXPOSURE WARNING
    $stmtUdhaarSum = $pdo->prepare("
        SELECT COALESCE(SUM(current_balance), 0) FROM customers
        WHERE business_id = :biz_id AND current_balance > 0
    ");
    $stmtUdhaarSum->execute(['biz_id' => $businessId]);
    $totalReceivables = (float)$stmtUdhaarSum->fetchColumn();

    $stmtMonthRev = $pdo->prepare("
        SELECT COALESCE(SUM(net_amount), 0) FROM sales
        WHERE business_id = :biz_id AND created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)
    ");
    $stmtMonthRev->execute(['biz_id' => $businessId]);
    $monthlyRev = (float)$stmtMonthRev->fetchColumn();

    if ($totalReceivables > 10000) {
        $ratio = $monthlyRev > 0 ? round(($totalReceivables / $monthlyRev) * 100, 1) : 100;
        $isHighRisk = $ratio > 35;

        $udhaarTitle = "Cash Flow Health: Udhaar Exposure at " . number_format($totalReceivables, 2) . " {$currency}";
        $udhaarEn = sprintf(
            "Total outstanding customer credit stands at %s %s (%s%% of 30-day turnover). %s",
            number_format($totalReceivables, 2),
            $currency,
            $ratio,
            $isHighRisk
                ? "HIGH RISK: Too much liquidity is locked in customer debt. Dispatch 1-click WhatsApp payment reminders today to safeguard vendor payments."
                : "Maintain steady recovery discipline by following up with pending accounts."
        );
        $udhaarUr = sprintf(
            "مارکیٹ میں گاہکوں کے ذمہ کل ادھار %s %s ہے (ماہانہ سیلز کا %s%%)۔ %s",
            number_format($totalReceivables, 2),
            $currency,
            $ratio,
            $isHighRisk
                ? "اہم انتباہ: ادھار کی رقم بہت زیادہ ہے۔ کیش فلو برقرار رکھنے کے لیے آج ہی واٹس ایپ پر یاد دہانی میسج بھیجیں۔"
                : "کیش ریکوری کے لیے باقاعدگی سے گاہکوں سے رابطہ رکھیں۔"
        );

        $generatedInsights[] = [
            'type'             => 'margin_recommendation',
            'severity'         => $isHighRisk ? 'high' : 'medium',
            'title'            => $udhaarTitle,
            'description'      => $udhaarEn,
            'urdu_translation' => $udhaarUr,
            'metadata'         => [
                'total_receivables' => $totalReceivables,
                'monthly_revenue'   => $monthlyRev,
                'exposure_ratio'    => $ratio
            ]
        ];
    }

    // =========================================================================
    // CACHE PERSISTENCE
    // =========================================================================
    $insertCacheStmt = $pdo->prepare("
        INSERT INTO ai_insights_cache (business_id, title, type, description, urdu_translation, severity)
        VALUES (:biz_id, :title, :type, :desc, :urdu, :severity)
    ");

    foreach ($generatedInsights as $ins) {
        $insertCacheStmt->execute([
            'biz_id'   => $businessId,
            'title'    => $ins['title'],
            'type'     => $ins['type'],
            'desc'     => $ins['description'],
            'urdu'     => $ins['urdu_translation'],
            'severity' => $ins['severity']
        ]);
    }

    jsonSuccess([
        'source'   => 'computed_fresh',
        'insights' => $generatedInsights
    ], 'AI Insights engine computed recommendations successfully');

} catch (Throwable $e) {
    jsonError('Server error: ' . $e->getMessage(), 500);
}
