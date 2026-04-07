# frozen_string_literal: true

# Solid Queue — queue DB 연결
# AI Job 동시성(max 2)은 config/queue.yml workers 섹션에서 설정
Rails.application.config.solid_queue.connects_to = { database: { writing: :queue } }
