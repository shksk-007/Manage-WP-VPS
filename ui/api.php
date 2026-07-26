<?php
session_start();

header('Content-Type: application/json');

// Default credentials. These should be changed after installation.
$admin_user = 'admin';
$admin_pass = 'admin';

$action = $_POST['action'] ?? ($_GET['action'] ?? '');

// Handle Authentication
if ($action === 'login') {
    $user = $_POST['username'] ?? '';
    $pass = $_POST['password'] ?? '';

    if ($user === $admin_user && $pass === $admin_pass) {
        $_SESSION['authenticated'] = true;
        echo json_encode(['success' => true]);
    } else {
        echo json_encode(['success' => false, 'error' => 'Invalid credentials']);
    }
    exit;
}

if ($action === 'logout') {
    session_destroy();
    echo json_encode(['success' => true]);
    exit;
}

if ($action === 'check_auth') {
    if (isset($_SESSION['authenticated']) && $_SESSION['authenticated'] === true) {
        echo json_encode(['authenticated' => true]);
    } else {
        echo json_encode(['authenticated' => false]);
    }
    exit;
}

// Ensure all other actions are authenticated
if (!isset($_SESSION['authenticated']) || $_SESSION['authenticated'] !== true) {
    http_response_code(401);
    echo json_encode(['error' => 'Unauthorized']);
    exit;
}

// Handle Command Execution
if ($action === 'execute') {
    $command = $_POST['command'] ?? '';
    
    // Expects an array of arguments, or a single string
    $args = $_POST['args'] ?? [];
    if (!is_array($args)) {
        $args = [$args];
    }

    // Validate command against whitelist to prevent arbitrary code execution
    $allowed_commands = [
        'list', 'status', 'doctor', 'monitor', 'health', 'security', 
        'create', 'delete', 'backup', 'restore', 'recover', 'update', 'migrate', 'logs',
        'login', 'backups-list', 'scan', 'activity', 'performance', 'fm'
    ];

    if (!in_array($command, $allowed_commands)) {
        http_response_code(400);
        echo json_encode(['error' => 'Invalid command']);
        exit;
    }

    // Securely escape arguments
    $escaped_args = '';
    foreach ($args as $arg) {
        if (!empty(trim($arg))) {
            $escaped_args .= ' ' . escapeshellarg($arg);
        }
    }

    // Execute via sudo (allowed by /etc/sudoers.d/wp-host-ui)
    // We redirect stderr to stdout to capture all output
    $full_cmd = "sudo /opt/wp-host/wp-host " . escapeshellarg($command) . $escaped_args . " 2>&1";
    
    $output = shell_exec($full_cmd);

    echo json_encode(['success' => true, 'output' => $output]);
    exit;
}

echo json_encode(['error' => 'Invalid action']);
?>
