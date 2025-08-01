-- role table
CREATE TABLE roles (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    description TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- partners table
CREATE TABLE partners (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE,
    domain VARCHAR(255),
    contact_name VARCHAR(255),
    contact_number VARCHAR(20),
    address TEXT,
    role_id INT,,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- properties table
CREATE TABLE properties (
    id INT AUTO_INCREMENT PRIMARY KEY,
    partner_id INT NOT NULL,
    name VARCHAR(255) NOT NULL,
    domain VARCHAR(255),
    contact_name VARCHAR(255),
    contact_number VARCHAR(20),
    email VARCHAR(255),
    address TEXT,
    status ENUM('active', 'inactive') DEFAULT 'active',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (partner_id) REFERENCES partners(id) ON DELETE CASCADE
);

-- categories table
CREATE TABLE categories (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- property_categories table
CREATE TABLE property_categories (
    id INT AUTO_INCREMENT PRIMARY KEY,
    property_id INT NOT NULL,
    category_id INT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (property_id) REFERENCES properties(id) ON DELETE CASCADE,
    FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE CASCADE,
    UNIQUE (property_id, category_id)  -- Prevent duplicates
);

-- assets table
CREATE TABLE assets (
    id INT AUTO_INCREMENT PRIMARY KEY,
    mux_asset_id VARCHAR(255) NOT NULL UNIQUE,
    mux_playback_id VARCHAR(255) UNIQUE,
    video_url TEXT,
    thumbnail_url TEXT,
    width INT,
    height INT,
    duration DOUBLE,
    status ENUM('waiting', 'ready', 'errored') DEFAULT 'waiting',
    transcoded_at DATETIME,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- videos table
CREATE TABLE videos(
    id INT AUTO_INCREMENT PRIMARY KEY,
    guid VARCHAR(255) NOT NULL UNIQUE,
    property_id INT NOT NULL,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    content_url TEXT,
    thumbnail_url TEXT, 
    keywords TEXT,
    category_id INT,
    height INT,
    width INT,
    duration DOUBLE,
    file_size BIGINT,
    asset_id INT,
    is_vertical BOOLEAN DEFAULT FALSE,
    status ENUM('pending', 'processing', 'live', 'failed') DEFAULT 'pending',
    stage_storage_path TEXT,
    creation_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    upload_method ENUM('csv', 'mrss', 'manual') NOT NULL,
    manual_upload_id INT,
    mrss_feed_id INT,
    csv_upload_batch_id INT,
    FOREIGN KEY (property_id) REFERENCES properties(id) ON DELETE CASCADE,
    FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET NULL,
    FOREIGN KEY (asset_id) REFERENCES assets(id) ON DELETE SET NULL,
    FOREIGN KEY (manual_upload_id) REFERENCES manual_uploads(id) ON DELETE SET NULL,
    FOREIGN KEY (mrss_feed_id) REFERENCES mrss_feeds(id) ON DELETE SET NULL,
    FOREIGN KEY (csv_upload_batch_id) REFERENCES csv_upload_batches(id) ON DELETE SET NULL
)

-- csv_uploads table
CREATE TABLE csv_upload_batches (
    id INT AUTO_INCREMENT PRIMARY KEY,
    property_id INT NOT NULL,
    csv_s3_url TEXT NOT NULL,
    uploaded_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (property_id) REFERENCES properties(id) ON DELETE CASCADE
);

-- mrss_feeds table
CREATE TABLE mrss_feeds (
    id INT AUTO_INCREMENT PRIMARY KEY,
    property_id INT NOT NULL,
    feed_url TEXT NOT NULL,
    cloudwatch_rule_arn VARCHAR(512),
    sync_frequency_minutes INT DEFAULT 60,
    update_interval INT NOT NULL,
    last_polled_at DATETIME,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (property_id) REFERENCES properties(id) ON DELETE CASCADE
);

-- mrss_feed_runs table
CREATE TABLE mrss_feed_runs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    mrss_feed_id INT NOT NULL,
    run_started_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    run_completed_at DATETIME,
    status ENUM('success', 'failed', 'partial') DEFAULT 'success',
    error_message TEXT,
    video_count INT DEFAULT 0,
    FOREIGN KEY (mrss_feed_id) REFERENCES mrss_feeds(id) ON DELETE CASCADE
);

-- manual_uploads table
CREATE TABLE manual_uploads (
    id INT AUTO_INCREMENT PRIMARY KEY,
    property_id INT NOT NULL,
    file_name VARCHAR(255) NOT NULL,
    s3_url TEXT NOT NULL,
    status ENUM('pending', 'submitted', 'error', 'completed') DEFAULT 'pending',
    error_message TEXT,
    uploaded_by VARCHAR(255),
    uploaded_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (property_id) REFERENCES properties(id) ON DELETE CASCADE
);


