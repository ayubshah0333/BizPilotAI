<?php
declare(strict_types=1);

require_once __DIR__ . '/config/database.php';

try {
    echo "[SEED] Starting database seeding for BizPilot AI...\n";
    $pdo = Database::getConnection();

    // Disable FK checks to allow clean re-seeding
    $pdo->exec("SET FOREIGN_KEY_CHECKS = 0;");

    $tables = [
        'ai_insights_cache',
        'purchase_items',
        'purchases',
        'udhaar_entries',
        'sale_items',
        'sales',
        'customers',
        'products',
        'categories',
        'users',
        'businesses'
    ];

    foreach ($tables as $t) {
        $pdo->exec("TRUNCATE TABLE `{$t}`;");
    }
    $pdo->exec("SET FOREIGN_KEY_CHECKS = 1;");

    echo "[SEED] Cleared existing tables.\n";

    // 1. Create Business
    $stmtBiz = $pdo->prepare("
        INSERT INTO businesses (id, name, owner_name, phone, currency, address)
        VALUES (1, 'Al-Madina Mart & General Store', 'Muhammad Bilal', '+923001234567', 'PKR', 'Shop #14, Main Commercial Market, F-10 Markaz, Islamabad')
    ");
    $stmtBiz->execute();
    $businessId = 1;
    echo "[SEED] Created business: Al-Madina Mart & General Store (ID: 1)\n";

    // 2. Create Users
    $passwordHash = password_hash('password123', PASSWORD_BCRYPT);
    $adminToken = 'test_token_al_madina_mart_secret_key_2026';

    $stmtUser = $pdo->prepare("
        INSERT INTO users (id, business_id, name, email, password_hash, role, api_token)
        VALUES 
        (1, 1, 'Muhammad Bilal', 'bilal@bizpilot.pk', :hash1, 'admin', :token1),
        (2, 1, 'Hamza Ali (Cashier)', 'cashier@bizpilot.pk', :hash2, 'cashier', 'cashier_token_bizpilot_2026')
    ");
    $stmtUser->execute([
        'hash1'  => $passwordHash,
        'token1' => $adminToken,
        'hash2'  => $passwordHash
    ]);
    echo "[SEED] Created users: admin (bilal@bizpilot.pk) with test token.\n";

    // 3. Create Categories
    $categories = [
        ['id' => 1, 'name' => 'Grocery & Staples', 'icon' => 'archive'],
        ['id' => 2, 'name' => 'Beverages & Cold Drinks', 'icon' => 'coffee'],
        ['id' => 3, 'name' => 'Dairy & Eggs', 'icon' => 'package'],
        ['id' => 4, 'name' => 'Personal Care', 'icon' => 'smile'],
        ['id' => 5, 'name' => 'Snacks & Biscuits', 'icon' => 'gift']
    ];
    $stmtCat = $pdo->prepare("INSERT INTO categories (id, business_id, name, icon) VALUES (:id, 1, :name, :icon)");
    foreach ($categories as $c) {
        $stmtCat->execute($c);
    }
    echo "[SEED] Created 5 categories.\n";

    // 4. Create Products
    $products = [
        // Category 1: Grocery & Staples
        [
            'id' => 1, 'cat' => 1, 'name' => 'Dalda Cooking Oil 1L Pouch',
            'sku' => 'SKU-DALDA-1L', 'barcode' => '8961014123456',
            'cost' => 520.00, 'sell' => 580.00, 'stock' => 45, 'thresh' => 10
        ],
        [
            'id' => 2, 'cat' => 1, 'name' => 'Basmati Rice Super Kernel 5kg',
            'sku' => 'SKU-RICE-5KG', 'barcode' => '8961014123463',
            'cost' => 1650.00, 'sell' => 1950.00, 'stock' => 24, 'thresh' => 5
        ],
        [
            'id' => 3, 'cat' => 1, 'name' => 'Tapal Danedar Tea 430g Box',
            'sku' => 'SKU-TAPAL-430G', 'barcode' => '8961014123470',
            'cost' => 590.00, 'sell' => 680.00, 'stock' => 35, 'thresh' => 8
        ],
        [
            'id' => 4, 'cat' => 1, 'name' => 'Shan Biryani Masala 50g Double Pack',
            'sku' => 'SKU-SHAN-BIRYANI', 'barcode' => '8961014123524',
            'cost' => 85.00, 'sell' => 110.00, 'stock' => 80, 'thresh' => 20
        ],
        [
            'id' => 5, 'cat' => 1, 'name' => 'National Tomato Ketchup 500g Pouch',
            'sku' => 'SKU-NAT-KETCHUP', 'barcode' => '8961014123548',
            'cost' => 240.00, 'sell' => 290.00, 'stock' => 32, 'thresh' => 6
        ],
        // Category 2: Beverages
        [
            'id' => 6, 'cat' => 2, 'name' => 'Coca-Cola Regular 1.5L Bottle',
            'sku' => 'SKU-COKE-15L', 'barcode' => '8961014123494',
            'cost' => 170.00, 'sell' => 210.00, 'stock' => 50, 'thresh' => 12
        ],
        [
            'id' => 7, 'cat' => 2, 'name' => 'Nestle Pure Life Mineral Water 1.5L',
            'sku' => 'SKU-NESTLE-WATER', 'barcode' => '8961014123579',
            'cost' => 70.00, 'sell' => 100.00, 'stock' => 95, 'thresh' => 20
        ],
        [
            'id' => 8, 'cat' => 2, 'name' => 'Vital Green Tea Mint 30 Tea Bags',
            'sku' => 'SKU-VITAL-GT30', 'barcode' => '8961014123586',
            'cost' => 220.00, 'sell' => 280.00, 'stock' => 3, 'thresh' => 6 // LOW STOCK!
        ],
        // Category 3: Dairy & Eggs
        [
            'id' => 9, 'cat' => 3, 'name' => "Olper's Full Cream Milk 1L UHT",
            'sku' => 'SKU-OLPERS-1L', 'barcode' => '8961014123487',
            'cost' => 260.00, 'sell' => 295.00, 'stock' => 65, 'thresh' => 15
        ],
        [
            'id' => 10, 'cat' => 3, 'name' => 'Farm Fresh Desi Eggs 1 Dozen',
            'sku' => 'SKU-DESI-EGGS-DOZ', 'barcode' => '8961014123616',
            'cost' => 340.00, 'sell' => 410.00, 'stock' => 40, 'thresh' => 10
        ],
        // Category 4: Personal Care
        [
            'id' => 11, 'cat' => 4, 'name' => 'Safeguard Lemon Fresh Soap 115g',
            'sku' => 'SKU-SAFEGUARD-115G', 'barcode' => '8961014123517',
            'cost' => 110.00, 'sell' => 140.00, 'stock' => 52, 'thresh' => 10
        ],
        [
            'id' => 12, 'cat' => 4, 'name' => 'Head & Shoulders Anti-Dandruff 360ml',
            'sku' => 'SKU-HS-SHAMPOO', 'barcode' => '8961014123593',
            'cost' => 620.00, 'sell' => 740.00, 'stock' => 2, 'thresh' => 5 // LOW STOCK!
        ],
        [
            'id' => 13, 'cat' => 4, 'name' => 'Surf Excel Quick Wash 1kg Bag',
            'sku' => 'SKU-SURF-1KG', 'barcode' => '8961014123562',
            'cost' => 440.00, 'sell' => 520.00, 'stock' => 22, 'thresh' => 5
        ],
        // Category 5: Snacks & Biscuits
        [
            'id' => 14, 'cat' => 5, 'name' => 'Peak Freans Sooper Biscuits Family Pack',
            'sku' => 'SKU-SOOPER-FP', 'barcode' => '8961014123555',
            'cost' => 125.00, 'sell' => 150.00, 'stock' => 85, 'thresh' => 15
        ],
        [
            'id' => 15, 'cat' => 5, 'name' => 'Kolson Macaroni Elbow 400g Pack',
            'sku' => 'SKU-KOLSON-MAC', 'barcode' => '8961014123531',
            'cost' => 145.00, 'sell' => 180.00, 'stock' => 28, 'thresh' => 5
        ],
        // Dead Stock item (Zero sales in last 30 days, high tied-up capital)
        [
            'id' => 16, 'cat' => 1, 'name' => 'Imported Extra Virgin Olive Oil 500ml Glass',
            'sku' => 'SKU-OLIVE-OIL-IMP', 'barcode' => '8961014123609',
            'cost' => 2100.00, 'sell' => 2700.00, 'stock' => 15, 'thresh' => 3
        ]
    ];

    $stmtProd = $pdo->prepare("
        INSERT INTO products (id, business_id, category_id, name, sku, barcode, cost_price, selling_price, stock_quantity, low_stock_threshold, is_active)
        VALUES (:id, 1, :cat, :name, :sku, :barcode, :cost, :sell, :stock, :thresh, 1)
    ");
    foreach ($products as $p) {
        $stmtProd->execute($p);
    }
    echo "[SEED] Created " . count($products) . " products.\n";

    // 5. Create Customers
    $customers = [
        [
            'id'      => 1,
            'name'    => 'Tariq Mehmood',
            'phone'   => '03005551122',
            'address' => 'House 23, Street 5, Sector F-10/2, Islamabad',
            'limit'   => 50000.00,
            'balance' => 14500.00
        ],
        [
            'id'      => 2,
            'name'    => 'Kamran Khan',
            'phone'   => '03217778899',
            'address' => 'Flat 4B, Silver Oak Luxury Apartments, Islamabad',
            'limit'   => 30000.00,
            'balance' => 6200.00
        ],
        [
            'id'      => 3,
            'name'    => 'Mrs. Farooq',
            'phone'   => '03334449988',
            'address' => 'Villa 12, Street 8, Sector E-11/3, Islamabad',
            'limit'   => 40000.00,
            'balance' => 0.00
        ],
        [
            'id'      => 4,
            'name'    => 'Usman Liaquat',
            'phone'   => '03451122334',
            'address' => 'Shop 8, Commercial Area F-10 Markaz, Islamabad',
            'limit'   => 25000.00,
            'balance' => 3800.00
        ]
    ];

    $stmtCust = $pdo->prepare("
        INSERT INTO customers (id, business_id, name, phone, address, credit_limit, current_balance)
        VALUES (:id, 1, :name, :phone, :address, :limit, :balance)
    ");
    foreach ($customers as $cu) {
        $stmtCust->execute($cu);
    }
    echo "[SEED] Created " . count($customers) . " customers.\n";

    // 6. Create Seed Purchases
    $stmtPurch = $pdo->prepare("
        INSERT INTO purchases (id, business_id, supplier_name, invoice_number, total_amount, created_at)
        VALUES 
        (1, 1, 'Metro Cash & Carry Wholesale', 'METRO-WH-9812', 48500.00, DATE_SUB(NOW(), INTERVAL 12 DAY)),
        (2, 1, 'Unilever Pakistan Distribution', 'UNI-PK-4421', 26400.00, DATE_SUB(NOW(), INTERVAL 5 DAY))
    ");
    $stmtPurch->execute();

    $stmtPurchItem = $pdo->prepare("
        INSERT INTO purchase_items (purchase_id, product_id, quantity, unit_cost, subtotal)
        VALUES
        (1, 1, 50, 520.00, 26000.00),
        (1, 2, 10, 1650.00, 16500.00),
        (1, 6, 35, 170.00, 5950.00),
        (2, 11, 60, 110.00, 6600.00),
        (2, 12, 15, 620.00, 9300.00),
        (2, 13, 24, 440.00, 10500.00)
    ");
    $stmtPurchItem->execute();
    echo "[SEED] Created supplier purchases.\n";

    // 7. Create Past Sales over last 14 days (Cash and Credit)
    $stmtSale = $pdo->prepare("
        INSERT INTO sales (id, business_id, invoice_number, customer_id, total_amount, discount_amount, net_amount, payment_method, payment_status, notes, created_at)
        VALUES (:id, 1, :inv, :cust, :tot, :disc, :net, :method, :status, :notes, :created)
    ");
    $stmtSaleItem = $pdo->prepare("
        INSERT INTO sale_items (sale_id, product_id, quantity, unit_price, cost_price, subtotal)
        VALUES (:sale_id, :product_id, :qty, :unit_price, :cost_price, :subtotal)
    ");

    $seedSales = [
        // Day -10: Cash sale
        [
            'id' => 1, 'inv' => 'INV-20261101-0001', 'cust' => null, 'tot' => 2530.00, 'disc' => 0.00, 'net' => 2530.00,
            'method' => 'CASH', 'status' => 'PAID', 'notes' => 'Walk-in regular groceries', 'days_ago' => 10,
            'items' => [
                ['pid' => 1, 'qty' => 2, 'price' => 580.00, 'cost' => 520.00], // Dalda (sell 1160, cost 1040)
                ['pid' => 3, 'qty' => 1, 'price' => 680.00, 'cost' => 590.00], // Tapal
                ['pid' => 9, 'qty' => 2, 'price' => 295.00, 'cost' => 260.00], // Olpers
                ['pid' => 6, 'qty' => 1, 'price' => 210.00, 'cost' => 170.00]  // Coke
            ]
        ],
        // Day -8: Credit sale to Tariq Mehmood
        [
            'id' => 2, 'inv' => 'INV-20261102-0002', 'cust' => 1, 'tot' => 7800.00, 'disc' => 0.00, 'net' => 7800.00,
            'method' => 'CREDIT', 'status' => 'UNPAID', 'notes' => 'Monthly family grocery order on credit', 'days_ago' => 8,
            'items' => [
                ['pid' => 2, 'qty' => 2, 'price' => 1950.00, 'cost' => 1650.00], // Super Basmati Rice
                ['pid' => 1, 'qty' => 4, 'price' => 580.00, 'cost' => 520.00],  // Dalda
                ['pid' => 9, 'qty' => 4, 'price' => 295.00, 'cost' => 260.00],  // Olpers
                ['pid' => 13, 'qty' => 1, 'price' => 520.00, 'cost' => 440.00], // Surf Excel
                ['pid' => 14, 'qty' => 6, 'price' => 150.00, 'cost' => 125.00]  // Sooper Biscuits
            ]
        ],
        // Day -5: Cash sale to Mrs. Farooq
        [
            'id' => 3, 'inv' => 'INV-20261105-0003', 'cust' => 3, 'tot' => 3620.00, 'disc' => 20.00, 'net' => 3600.00,
            'method' => 'CASH', 'status' => 'PAID', 'notes' => 'Store pickup paid cash', 'days_ago' => 5,
            'items' => [
                ['pid' => 2, 'qty' => 1, 'price' => 1950.00, 'cost' => 1650.00],
                ['pid' => 3, 'qty' => 2, 'price' => 680.00, 'cost' => 590.00],
                ['pid' => 11, 'qty' => 2, 'price' => 140.00, 'cost' => 110.00]
            ]
        ],
        // Day -3: Credit sale to Kamran Khan
        [
            'id' => 4, 'inv' => 'INV-20261107-0004', 'cust' => 2, 'tot' => 6200.00, 'disc' => 0.00, 'net' => 6200.00,
            'method' => 'CREDIT', 'status' => 'UNPAID', 'notes' => 'Apartment provisions on credit', 'days_ago' => 3,
            'items' => [
                ['pid' => 1, 'qty' => 3, 'price' => 580.00, 'cost' => 520.00],
                ['pid' => 9, 'qty' => 6, 'price' => 295.00, 'cost' => 260.00],
                ['pid' => 10, 'qty' => 3, 'price' => 410.00, 'cost' => 340.00],
                ['pid' => 6, 'qty' => 6, 'price' => 210.00, 'cost' => 170.00],
                ['pid' => 7, 'qty' => 2, 'price' => 100.00, 'cost' => 70.00]
            ]
        ],
        // Day -1: Credit sale to Tariq Mehmood
        [
            'id' => 5, 'inv' => 'INV-20261109-0005', 'cust' => 1, 'tot' => 6700.00, 'disc' => 0.00, 'net' => 6700.00,
            'method' => 'CREDIT', 'status' => 'UNPAID', 'notes' => 'Second grocery haul for relatives', 'days_ago' => 1,
            'items' => [
                ['pid' => 2, 'qty' => 2, 'price' => 1950.00, 'cost' => 1650.00],
                ['pid' => 1, 'qty' => 2, 'price' => 580.00, 'cost' => 520.00],
                ['pid' => 3, 'qty' => 2, 'price' => 680.00, 'cost' => 590.00],
                ['pid' => 5, 'qty' => 1, 'price' => 290.00, 'cost' => 240.00]
            ]
        ],
        // Today: Morning cash counter sale
        [
            'id' => 6, 'inv' => 'INV-20261110-0006', 'cust' => null, 'tot' => 1840.00, 'disc' => 0.00, 'net' => 1840.00,
            'method' => 'CASH', 'status' => 'PAID', 'notes' => 'Morning snacks and beverages', 'days_ago' => 0,
            'items' => [
                ['pid' => 9, 'qty' => 2, 'price' => 295.00, 'cost' => 260.00],
                ['pid' => 10, 'qty' => 1, 'price' => 410.00, 'cost' => 340.00],
                ['pid' => 14, 'qty' => 4, 'price' => 150.00, 'cost' => 125.00],
                ['pid' => 7, 'qty' => 2, 'price' => 100.00, 'cost' => 70.00],
                ['pid' => 4, 'qty' => 3, 'price' => 110.00, 'cost' => 85.00]
            ]
        ]
    ];

    foreach ($seedSales as $s) {
        $createdAt = date('Y-m-d H:i:s', strtotime("-{$s['days_ago']} days"));
        $stmtSale->execute([
            'id'      => $s['id'],
            'inv'     => $s['inv'],
            'cust'    => $s['cust'],
            'tot'     => $s['tot'],
            'disc'    => $s['disc'],
            'net'     => $s['net'],
            'method'  => $s['method'],
            'status'  => $s['status'],
            'notes'   => $s['notes'],
            'created' => $createdAt
        ]);

        foreach ($s['items'] as $it) {
            $subtotal = round($it['qty'] * $it['price'], 2);
            $stmtSaleItem->execute([
                'sale_id'    => $s['id'],
                'product_id' => $it['pid'],
                'qty'        => $it['qty'],
                'unit_price' => $it['price'],
                'cost_price' => $it['cost'],
                'subtotal'   => $subtotal
            ]);
        }
    }
    echo "[SEED] Created " . count($seedSales) . " realistic sales and item records.\n";

    // 8. Create Udhaar Entries
    // Tariq Mehmood: opening balance 5000 (day -15), credit sale #2 (7800, day -8), partial payment 5000 (day -6), credit sale #5 (6700, day -1) -> total 14,500 balance!
    $udhaarRecords = [
        // Tariq Mehmood
        [
            'biz_id' => 1, 'cust_id' => 1, 'sale_id' => null, 'type' => 'CREDIT', 'amount' => 5000.00,
            'notes' => 'Opening balance from previous manual register', 'days_ago' => 15
        ],
        [
            'biz_id' => 1, 'cust_id' => 1, 'sale_id' => 2, 'type' => 'CREDIT', 'amount' => 7800.00,
            'notes' => 'Credit sale invoice #INV-20261102-0002', 'days_ago' => 8
        ],
        [
            'biz_id' => 1, 'cust_id' => 1, 'sale_id' => null, 'type' => 'PAYMENT', 'amount' => 5000.00,
            'notes' => 'Cash received at shop counter by Bilal', 'days_ago' => 6
        ],
        [
            'biz_id' => 1, 'cust_id' => 1, 'sale_id' => 5, 'type' => 'CREDIT', 'amount' => 6700.00,
            'notes' => 'Credit sale invoice #INV-20261109-0005', 'days_ago' => 1
        ],
        // Kamran Khan: credit sale #4 (6200, day -3)
        [
            'biz_id' => 1, 'cust_id' => 2, 'sale_id' => 4, 'type' => 'CREDIT', 'amount' => 6200.00,
            'notes' => 'Credit sale invoice #INV-20261107-0004', 'days_ago' => 3
        ],
        // Usman Liaquat: opening credit 3800
        [
            'biz_id' => 1, 'cust_id' => 4, 'sale_id' => null, 'type' => 'CREDIT', 'amount' => 3800.00,
            'notes' => 'Credit taken for commercial supplies', 'days_ago' => 4
        ]
    ];

    $stmtUdh = $pdo->prepare("
        INSERT INTO udhaar_entries (business_id, customer_id, sale_id, type, amount, notes, created_at)
        VALUES (:biz_id, :cust_id, :sale_id, :type, :amount, :notes, :created)
    ");
    foreach ($udhaarRecords as $u) {
        $createdAt = date('Y-m-d H:i:s', strtotime("-{$u['days_ago']} days"));
        $stmtUdh->execute([
            'biz_id'   => $u['biz_id'],
            'cust_id'  => $u['cust_id'],
            'sale_id'  => $u['sale_id'],
            'type'     => $u['type'],
            'amount'   => $u['amount'],
            'notes'    => $u['notes'],
            'created'  => $createdAt
        ]);
    }
    echo "[SEED] Created " . count($udhaarRecords) . " udhaar credit & payment ledger records.\n";

    echo "[SEED] Database seeding successfully completed! All tables populated.\n";

} catch (Throwable $e) {
    echo "[SEED ERROR] " . $e->getMessage() . "\n";
    exit(1);
}
