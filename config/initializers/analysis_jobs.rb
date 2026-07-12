# Solid Queue worker processes deserialize job classes before executing them.
# Require analysis jobs explicitly so production workers do not depend on lazy
# autoload timing for long-running AI queues.
require Rails.root.join("app/jobs/application_job").to_s
require Rails.root.join("app/jobs/analyze_webpage_job").to_s
require Rails.root.join("app/jobs/analyze_webpage_analysis_job").to_s
require Rails.root.join("app/jobs/analyze_youtube_job").to_s
