-- UTC days, page loads and activations; never unique people or installs.
-- 28 UTC calendar dates including the current, incomplete day.
SELECT day, page, source,
       SUM(CASE WHEN event = 'page_view' THEN count ELSE 0 END) AS page_loads,
       SUM(CASE WHEN event = 'app_store_clicked' THEN count ELSE 0 END) AS download_activations
FROM website_acquisition_daily
WHERE day BETWEEN date('now', '-27 days') AND date('now')
GROUP BY day, page, source
ORDER BY day DESC, page, source;
