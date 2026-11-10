<?php
declare(strict_types=1);

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../helpers/response.php';
require_once __DIR__ . '/../helpers/auth.php';

setupCors();

$pdo = Database::getConnection();
$requestMethod = $_SERVER['REQUEST_METHOD'];
$data = getRequestData();
$action = $data['action'] ?? ($requestMethod === 'GET' ? 'profile' : 'login');

try {
    switch ($action) {
        case 'register':
            if ($requestMethod !== 'POST') {
                jsonError('Method Not Allowed for register. Use POST.', 405);
            }

            $businessName = sanitizeString($data['business_name'] ?? '');
            $ownerName = sanitizeString($data['owner_name'] ?? '');
            $phone = sanitizeString($data['phone'] ?? '');
            $currency = sanitizeString($data['currency'] ?? 'PKR');
            $address = sanitizeString($data['address'] ?? '');
            $email = filter_var($data['email'] ?? '', FILTER_VALIDATE_EMAIL);
            $password = $data['password'] ?? '';

            if (empty($businessName) || empty($ownerName) || empty($phone) || !$email || empty($password)) {
                jsonError('Missing required fields: business_name, owner_name, phone, valid email, and password.', 422);
            }

            if (strlen($password) < 6) {
                jsonError('Password must be at least 6 characters long.', 422);
            }

            // Check if email already exists
            $checkStmt = $pdo->prepare("SELECT id FROM users WHERE email = :email LIMIT 1");
            $checkStmt->execute(['email' => $email]);
            if ($checkStmt->fetch()) {
                jsonError('User with this email already exists.', 409);
            }

            $pdo->beginTransaction();

            // 1. Insert business
            $stmtBiz = $pdo->prepare("
                INSERT INTO businesses (name, owner_name, phone, currency, address)
                VALUES (:name, :owner_name, :phone, :currency, :address)
            ");
            $stmtBiz->execute([
                'name'       => $businessName,
                'owner_name' => $ownerName,
                'phone'      => $phone,
                'currency'   => $currency,
                'address'    => $address
            ]);
            $businessId = (int)$pdo->lastInsertId();

            // 2. Insert user
            $passwordHash = password_hash($password, PASSWORD_BCRYPT);
            $apiToken = generateApiToken();

            $stmtUser = $pdo->prepare("
                INSERT INTO users (business_id, name, email, password_hash, role, api_token)
                VALUES (:business_id, :name, :email, :password_hash, 'admin', :api_token)
            ");
            $stmtUser->execute([
                'business_id'   => $businessId,
                'name'          => $ownerName,
                'email'         => $email,
                'password_hash' => $passwordHash,
                'api_token'     => $apiToken
            ]);
            $userId = (int)$pdo->lastInsertId();

            // 3. Insert initial default categories
            $defaultCategories = [
                ['name' => 'General', 'icon' => 'shopping-bag'],
                ['name' => 'Grocery & Staples', 'icon' => 'archive'],
                ['name' => 'Beverages', 'icon' => 'coffee'],
                ['name' => 'Personal Care', 'icon' => 'smile'],
                ['name' => 'Snacks & Confectionery', 'icon' => 'gift']
            ];
            $stmtCat = $pdo->prepare("INSERT INTO categories (business_id, name, icon) VALUES (:business_id, :name, :icon)");
            foreach ($defaultCategories as $cat) {
                $stmtCat->execute([
                    'business_id' => $businessId,
                    'name'        => $cat['name'],
                    'icon'        => $cat['icon']
                ]);
            }

            $pdo->commit();

            jsonSuccess([
                'token' => $apiToken,
                'user'  => [
                    'id'    => $userId,
                    'name'  => $ownerName,
                    'email' => $email,
                    'role'  => 'admin'
                ],
                'business' => [
                    'id'         => $businessId,
                    'name'       => $businessName,
                    'owner_name' => $ownerName,
                    'phone'      => $phone,
                    'currency'   => $currency,
                    'address'    => $address
                ]
            ], 'Registration successful', 201);
            break;

        case 'login':
            if ($requestMethod !== 'POST') {
                jsonError('Method Not Allowed for login. Use POST.', 405);
            }

            $email = filter_var($data['email'] ?? '', FILTER_VALIDATE_EMAIL);
            $password = $data['password'] ?? '';

            if (!$email || empty($password)) {
                jsonError('Please provide a valid email and password.', 422);
            }

            $stmt = $pdo->prepare("
                SELECT u.id, u.business_id, u.name, u.email, u.password_hash, u.role, u.api_token,
                       b.name AS business_name, b.owner_name, b.phone AS business_phone, b.currency, b.address AS business_address
                FROM users u
                INNER JOIN businesses b ON u.business_id = b.id
                WHERE u.email = :email
                LIMIT 1
            ");
            $stmt->execute(['email' => $email]);
            $user = $stmt->fetch(PDO::FETCH_ASSOC);

            if (!$user || !password_verify($password, $user['password_hash'])) {
                jsonError('Invalid email or password credentials.', 401);
            }

            // Refresh or assign token if missing
            $token = $user['api_token'];
            if (empty($token)) {
                $token = generateApiToken();
                $updStmt = $pdo->prepare("UPDATE users SET api_token = :token WHERE id = :id");
                $updStmt->execute(['token' => $token, 'id' => $user['id']]);
            }

            jsonSuccess([
                'token' => $token,
                'user'  => [
                    'id'          => (int)$user['id'],
                    'business_id' => (int)$user['business_id'],
                    'name'        => $user['name'],
                    'email'       => $user['email'],
                    'role'        => $user['role']
                ],
                'business' => [
                    'id'         => (int)$user['business_id'],
                    'name'       => $user['business_name'],
                    'owner_name' => $user['owner_name'],
                    'phone'      => $user['business_phone'],
                    'currency'   => $user['currency'],
                    'address'    => $user['business_address']
                ]
            ], 'Login successful');
            break;

        case 'profile':
            $user = authenticateUser($pdo);
            jsonSuccess([
                'user' => [
                    'id'          => (int)$user['id'],
                    'business_id' => (int)$user['business_id'],
                    'name'        => $user['name'],
                    'email'       => $user['email'],
                    'role'        => $user['role'],
                    'created_at'  => $user['created_at']
                ],
                'business' => [
                    'id'         => (int)$user['business_id'],
                    'name'       => $user['business_name'],
                    'owner_name' => $user['owner_name'],
                    'phone'      => $user['business_phone'],
                    'currency'   => $user['currency'],
                    'address'    => $user['business_address']
                ]
            ], 'Profile retrieved successfully');
            break;

        default:
            jsonError("Invalid action '{$action}'. Valid actions: register, login, profile.", 400);
            break;
    }
} catch (Throwable $e) {
    if ($pdo->inTransaction()) {
        $pdo->rollBack();
    }
    jsonError('Server error: ' . $e->getMessage(), 500);
}
