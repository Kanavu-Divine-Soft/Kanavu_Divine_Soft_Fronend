-- Create the database
CREATE DATABASE IF NOT EXISTS temple_onboarding;
USE temple_onboarding;

-- Create the users table
CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    mobile VARCHAR(15) NOT NULL UNIQUE,
    email VARCHAR(255),
    password VARCHAR(255) NOT NULL,
    role VARCHAR(50) DEFAULT 'Member',
    status ENUM('Pending', 'Active', 'Inactive') DEFAULT 'Pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Insert a default admin user
-- Password is 'admin123' (hashed using bcrypt in a real scenario)
-- For demonstration, I'll use a plain text placeholder or a sample hash
INSERT INTO users (name, mobile, email, password, role, status) 
VALUES ('Administrator', '9876543210', 'admin@temple.com', '$2b$12$cyDV3ng7c8fWje1zKovqCenMCQyZRJV3hGkm.hDpKfa7xR/cm.5Xy', 'Admin', 'Active')
ON DUPLICATE KEY UPDATE name=name;
