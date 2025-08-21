CREATE TABLE content_providers (
  id            INT AUTO_INCREMENT PRIMARY KEY,
  name          VARCHAR(255) NOT NULL,
  type          VARCHAR(50),
  email         VARCHAR(255),
  visibility    VARCHAR(50),
  created_at    TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at    TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE provider_shares (
  provider_id     INT NOT NULL,
  shared_with_id  INT NOT NULL,
  PRIMARY KEY (provider_id, shared_with_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE contacts (
  id                   INT AUTO_INCREMENT PRIMARY KEY,
  content_provider_id  INT NOT NULL,
  type                 VARCHAR(50),
  name                 VARCHAR(255),
  email                VARCHAR(255),
  phone                VARCHAR(50),
  details              JSON,
  created_at           TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at           TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE sources (
  id                   INT AUTO_INCREMENT PRIMARY KEY,
  name                 VARCHAR(255) NOT NULL,
  type                 VARCHAR(50),
  url                  VARCHAR(1024),
  file_path            VARCHAR(1024),
  content_provider_id  INT,
  visibility           VARCHAR(50),
  status               VARCHAR(50),
  created_at           TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at           TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE source_shares (
  source_id       INT NOT NULL,
  shared_with_id  INT NOT NULL,
  PRIMARY KEY (source_id, shared_with_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE tags (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  name        VARCHAR(100) NOT NULL,
  description TEXT,
  type        VARCHAR(50),
  created_at  TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE source_tags (
  source_id INT NOT NULL,
  tag_id    INT NOT NULL,
  PRIMARY KEY (source_id, tag_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE videos (
  id                   INT AUTO_INCREMENT PRIMARY KEY,
  title                VARCHAR(255),
  description          TEXT,
  video_url            VARCHAR(1024),
  source_id            INT,
  content_provider_id  INT,
  thumbnail_url        VARCHAR(1024),
  gif_preview_url      VARCHAR(1024),
  additional_metadata  JSON,
  duration             INT,
  format               VARCHAR(50),
  state                VARCHAR(50),
  status               VARCHAR(50),
  ingested_at          TIMESTAMP NULL,
  processed_at         TIMESTAMP NULL,
  updated_at           TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE video_tags (
  video_id INT NOT NULL,
  tag_id   INT NOT NULL,
  PRIMARY KEY (video_id, tag_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE assets (
  id                   INT AUTO_INCREMENT PRIMARY KEY,
  video_id             INT,
  transcoder_type      VARCHAR(50),
  transcoder_asset_id  VARCHAR(255),
  status               VARCHAR(50),
  playback_id          VARCHAR(255),
  submission_at        TIMESTAMP NULL,
  completed_at         TIMESTAMP NULL,
  updated_at           TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE transcoder_logs (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  asset_id    INT,
  event_type  VARCHAR(100),
  payload     JSON,
  received_at TIMESTAMP NULL,
  processed   BOOLEAN
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE mrss_audit_logs (
  id                  INT AUTO_INCREMENT PRIMARY KEY,
  source_id           INT,
  status              VARCHAR(50),
  state               VARCHAR(50),
  num_items_ingested  INT,
  details             JSON,
  started_at          TIMESTAMP NULL,
  completed_at        TIMESTAMP NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE upload_logs (
  id           INT AUTO_INCREMENT PRIMARY KEY,
  source_id    INT,
  status       VARCHAR(50),
  state        VARCHAR(50),
  file_size    BIGINT,
  details      JSON,
  started_at   TIMESTAMP NULL,
  completed_at TIMESTAMP NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE csv_processing_logs (
  id              INT AUTO_INCREMENT PRIMARY KEY,
  source_id       INT,
  status          VARCHAR(50),
  state           VARCHAR(50),
  rows_processed  INT,
  details         JSON,
  started_at      TIMESTAMP NULL,
  completed_at    TIMESTAMP NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

---------------------------------------------------------------------------------------------


CREATE INDEX idx_contacts_provider             ON contacts (content_provider_id);
CREATE INDEX idx_sources_provider              ON sources (content_provider_id);
CREATE INDEX idx_source_shares_source          ON source_shares (source_id);
CREATE INDEX idx_source_shares_shared_with     ON source_shares (shared_with_id);
CREATE INDEX idx_source_tags_source            ON source_tags (source_id);
CREATE INDEX idx_source_tags_tag               ON source_tags (tag_id);
CREATE INDEX idx_videos_source                 ON videos (source_id);
CREATE INDEX idx_videos_provider               ON videos (content_provider_id);
CREATE INDEX idx_video_tags_video              ON video_tags (video_id);
CREATE INDEX idx_video_tags_tag                ON video_tags (tag_id);
CREATE INDEX idx_assets_video                  ON assets (video_id);
CREATE INDEX idx_transcoder_logs_asset         ON transcoder_logs (asset_id);
CREATE INDEX idx_mrss_audit_logs_source        ON mrss_audit_logs (source_id);
CREATE INDEX idx_upload_logs_source            ON upload_logs (source_id);
CREATE INDEX idx_csv_processing_logs_source    ON csv_processing_logs (source_id);

CREATE INDEX idx_provider_shares_provider      ON provider_shares (provider_id);
CREATE INDEX idx_provider_shares_shared_with   ON provider_shares (shared_with_id);

---------------------------------------------------------------------------------------------


ALTER TABLE provider_shares
  ADD CONSTRAINT fk_provider_shares_provider
    FOREIGN KEY (provider_id) REFERENCES content_providers(id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT fk_provider_shares_shared_with
    FOREIGN KEY (shared_with_id) REFERENCES content_providers(id)
    ON DELETE CASCADE ON UPDATE CASCADE;

-- Contacts ↔ Content Providers
ALTER TABLE contacts
  ADD CONSTRAINT fk_contacts_provider
    FOREIGN KEY (content_provider_id) REFERENCES content_providers(id)
    ON DELETE CASCADE ON UPDATE CASCADE;

-- Sources ↔ Content Providers
ALTER TABLE sources
  ADD CONSTRAINT fk_sources_provider
    FOREIGN KEY (content_provider_id) REFERENCES content_providers(id)
    ON DELETE SET NULL ON UPDATE CASCADE;

-- Source shares: share a Source with a Provider
ALTER TABLE source_shares
  ADD CONSTRAINT fk_source_shares_source
    FOREIGN KEY (source_id) REFERENCES sources(id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT fk_source_shares_shared_with
    FOREIGN KEY (shared_with_id) REFERENCES content_providers(id)
    ON DELETE CASCADE ON UPDATE CASCADE;

-- Source tags
ALTER TABLE source_tags
  ADD CONSTRAINT fk_source_tags_source
    FOREIGN KEY (source_id) REFERENCES sources(id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT fk_source_tags_tag
    FOREIGN KEY (tag_id) REFERENCES tags(id)
    ON DELETE CASCADE ON UPDATE CASCADE;

-- Videos ↔ Sources / Providers
ALTER TABLE videos
  ADD CONSTRAINT fk_videos_source
    FOREIGN KEY (source_id) REFERENCES sources(id)
    ON DELETE SET NULL ON UPDATE CASCADE,
  ADD CONSTRAINT fk_videos_provider
    FOREIGN KEY (content_provider_id) REFERENCES content_providers(id)
    ON DELETE SET NULL ON UPDATE CASCADE;

-- Video tags
ALTER TABLE video_tags
  ADD CONSTRAINT fk_video_tags_video
    FOREIGN KEY (video_id) REFERENCES videos(id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT fk_video_tags_tag
    FOREIGN KEY (tag_id) REFERENCES tags(id)
    ON DELETE CASCADE ON UPDATE CASCADE;

-- Assets ↔ Videos
ALTER TABLE assets
  ADD CONSTRAINT fk_assets_video
    FOREIGN KEY (video_id) REFERENCES videos(id)
    ON DELETE CASCADE ON UPDATE CASCADE;

-- Transcoder logs ↔ Assets
ALTER TABLE transcoder_logs
  ADD CONSTRAINT fk_transcoder_logs_asset
    FOREIGN KEY (asset_id) REFERENCES assets(id)
    ON DELETE CASCADE ON UPDATE CASCADE;

-- Logs ↔ Sources
ALTER TABLE mrss_audit_logs
  ADD CONSTRAINT fk_mrss_audit_logs_source
    FOREIGN KEY (source_id) REFERENCES sources(id)
    ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE upload_logs
  ADD CONSTRAINT fk_upload_logs_source
    FOREIGN KEY (source_id) REFERENCES sources(id)
    ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE csv_processing_logs
  ADD CONSTRAINT fk_csv_processing_logs_source
    FOREIGN KEY (source_id) REFERENCES sources(id)
    ON DELETE CASCADE ON UPDATE CASCADE;