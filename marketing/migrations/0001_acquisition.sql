-- Daily aggregate counters. No event log or visitor/location identifiers.
CREATE TABLE IF NOT EXISTS website_acquisition_daily (
  day TEXT NOT NULL,
  event TEXT NOT NULL CHECK (event IN ('page_view', 'app_store_clicked')),
  page TEXT NOT NULL,
  placement TEXT NOT NULL,
  source TEXT NOT NULL,
  count INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (day, event, page, placement, source)
) WITHOUT ROWID;
