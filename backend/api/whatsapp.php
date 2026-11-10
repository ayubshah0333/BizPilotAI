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
$type = strtolower(trim((string)($data['type'] ?? '')));

function formatWhatsAppPhone(?string $phone): string
{
    if (empty($phone)) {
        return '';
    }
    // Remove all non-digits
    $clean = preg_replace('/\D/', '', $phone);
    // If starts with 0 (Pakistani standard like 03001234567), replace leading 0 with 92
    if (str_starts_with($clean, '0')) {
        $clean = '92' . substr($clean, 1);
    }
    return $clean;
}

try {
    switch ($type) {
        case 'invoice':
            $saleId = !empty($data['sale_id']) ? (int)$data['sale_id'] : (!empty($data['id']) ? (int)$data['id'] : null);
            $invoiceNumber = !empty($data['invoice_number']) ? trim((string)$data['invoice_number']) : null;

            if (!$saleId && !$invoiceNumber) {
                jsonError('Either sale_id or invoice_number is required.', 422);
            }

            $where = $saleId ? "s.id = :sale_id" : "s.invoice_number = :invoice_num";
            $paramKey = $saleId ? 'sale_id' : 'invoice_num';
            $paramVal = $saleId ?: $invoiceNumber;

            $saleStmt = $pdo->prepare("
                SELECT s.*,
                       c.name AS customer_name, c.phone AS customer_phone, c.current_balance AS customer_balance,
                       b.name AS business_name, b.owner_name, b.phone AS business_phone, b.currency, b.address AS business_address
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

            $itemsStmt = $pdo->prepare("
                SELECT si.*, p.name AS product_name
                FROM sale_items si
                INNER JOIN products p ON si.product_id = p.id
                WHERE si.sale_id = :sale_id
            ");
            $itemsStmt->execute(['sale_id' => (int)$sale['id']]);
            $items = $itemsStmt->fetchAll(PDO::FETCH_ASSOC);

            $bizName = $sale['business_name'];
            $invNum = $sale['invoice_number'];
            $custName = $sale['customer_name'] ?? 'Valued Customer';
            $currency = $sale['currency'] ?? 'PKR';
            $date = date('d-M-Y h:i A', strtotime($sale['created_at']));

            $lines = [];
            $lines[] = "🧾 *INVOICE / بل رسید*";
            $lines[] = "🏪 *{$bizName}*";
            if (!empty($sale['business_phone'])) {
                $lines[] = "📞 Contact: {$sale['business_phone']}";
            }
            $lines[] = "--------------------------------";
            $lines[] = "📄 *Invoice #:* `{$invNum}`";
            $lines[] = "📅 *Date:* {$date}";
            $lines[] = "👤 *Customer:* {$custName}";
            $lines[] = "💳 *Payment:* {$sale['payment_method']} ({$sale['payment_status']})";
            $lines[] = "--------------------------------";
            $lines[] = "*ITEMS / تفصیلات:*";

            foreach ($items as $idx => $it) {
                $num = $idx + 1;
                $lines[] = "{$num}. *{$it['product_name']}*";
                $lines[] = "   {$it['quantity']} x {$it['unit_price']} {$currency} = *{$it['subtotal']} {$currency}*";
            }

            $lines[] = "--------------------------------";
            $lines[] = "Subtotal: " . number_format((float)$sale['total_amount'], 2) . " {$currency}";
            if ((float)$sale['discount_amount'] > 0) {
                $lines[] = "Discount: -" . number_format((float)$sale['discount_amount'], 2) . " {$currency}";
            }
            $lines[] = "💰 *Total Net: " . number_format((float)$sale['net_amount'], 2) . " {$currency}*";

            if ($sale['payment_method'] === 'CREDIT' || (float)($sale['customer_balance'] ?? 0) > 0) {
                $lines[] = "⚠️ *Current Balance (بقایا کھاتہ): " . number_format((float)$sale['customer_balance'], 2) . " {$currency}*";
            }

            $lines[] = "--------------------------------";
            $lines[] = "تشریف آوری کا شکریہ! جزاک اللہ خیراً۔";
            $lines[] = "Thank you for your business! Powered by BizPilot AI.";

            $messageText = implode("\n", $lines);
            $cleanPhone = formatWhatsAppPhone($sale['customer_phone']);
            $whatsappUrl = "https://wa.me/{$cleanPhone}?text=" . rawurlencode($messageText);

            jsonSuccess([
                'type'           => 'invoice',
                'customer_phone' => $sale['customer_phone'],
                'clean_phone'    => $cleanPhone,
                'message_text'   => $messageText,
                'whatsapp_url'   => $whatsappUrl
            ], 'WhatsApp invoice link generated');
            break;

        case 'udhaar_reminder':
            $customerId = !empty($data['customer_id']) ? (int)$data['customer_id'] : null;
            if (!$customerId) {
                jsonError('Customer ID is required.', 422);
            }

            $custStmt = $pdo->prepare("
                SELECT c.*, b.name AS business_name, b.phone AS business_phone, b.currency, b.owner_name
                FROM customers c
                INNER JOIN businesses b ON c.business_id = b.id
                WHERE c.id = :id AND c.business_id = :business_id
                LIMIT 1
            ");
            $custStmt->execute(['id' => $customerId, 'business_id' => $businessId]);
            $customer = $custStmt->fetch(PDO::FETCH_ASSOC);

            if (!$customer) {
                jsonError('Customer not found.', 404);
            }

            $balance = (float)$customer['current_balance'];
            if ($balance <= 0) {
                jsonError('Customer currently has no outstanding balance.', 400);
            }

            $bizName = $customer['business_name'];
            $custName = $customer['name'];
            $currency = $customer['currency'] ?? 'PKR';
            $formattedBalance = number_format($balance, 2);

            $lines = [];
            $lines[] = "السلام علیکم محترم *{$custName}* صاحب،";
            $lines[] = "امید ہے آپ خیریت سے ہوں گے۔";
            $lines[] = "";
            $lines[] = "یہ *{$bizName}* کی طرف سے آپ کے کھاتے کی مؤدبانہ یاد دہانی ہے۔";
            $lines[] = "آپ کے کھاتے کا موجودہ واجب الادا بیلنس (بقایا ادھار):";
            $lines[] = "💵 *{$formattedBalance} {$currency}*";
            $lines[] = "";
            $lines[] = "برائے مہربانی سہولت کے مطابق تشریف لا کر یا آن لائن ادائیگی فرما دیں۔";
            $lines[] = "آپ کے تعاون کا بے حد شکریہ! جزاک اللہ خیراً۔";
            $lines[] = "";
            $lines[] = "--------------------------------";
            $lines[] = "Dear {$custName}, gentle reminder from {$bizName}. Your outstanding balance is *{$formattedBalance} {$currency}*. Kindly settle at your earliest convenience.";
            $lines[] = "📞 Contact: {$customer['business_phone']}";

            $messageText = implode("\n", $lines);
            $cleanPhone = formatWhatsAppPhone($customer['phone']);
            $whatsappUrl = "https://wa.me/{$cleanPhone}?text=" . rawurlencode($messageText);

            jsonSuccess([
                'type'             => 'udhaar_reminder',
                'customer_id'      => $customerId,
                'customer_name'    => $custName,
                'customer_phone'   => $customer['phone'],
                'clean_phone'      => $cleanPhone,
                'current_balance'  => $balance,
                'message_text'     => $messageText,
                'whatsapp_url'     => $whatsappUrl
            ], 'WhatsApp Udhaar reminder generated');
            break;

        default:
            jsonError("Invalid type '{$type}'. Valid types: 'invoice' or 'udhaar_reminder'.", 400);
            break;
    }
} catch (Throwable $e) {
    jsonError('Server error: ' . $e->getMessage(), 500);
}
