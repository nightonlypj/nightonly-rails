# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2023_04_08_084721) do

  create_table "admin_users", charset: "utf8", collation: "utf8_bin", comment: "管理者", force: :cascade do |t|
    t.string "name", null: false, comment: "氏名"
    t.string "email", default: "", null: false, comment: "メールアドレス"
    t.string "encrypted_password", default: "", null: false, comment: "暗号化されたパスワード"
    t.string "reset_password_token", comment: "パスワードリセットトークン"
    t.datetime "reset_password_sent_at", comment: "パスワードリセット送信日時"
    t.datetime "remember_created_at", comment: "ログイン状態維持開始日時"
    t.integer "sign_in_count", default: 0, null: false, comment: "ログイン回数"
    t.datetime "current_sign_in_at", comment: "現在のログイン日時"
    t.datetime "last_sign_in_at", comment: "最終ログイン日時"
    t.string "current_sign_in_ip", comment: "現在のログインIPアドレス"
    t.string "last_sign_in_ip", comment: "最終ログインIPアドレス"
    t.string "confirmation_token", comment: "メールアドレス確認トークン"
    t.datetime "confirmed_at", comment: "メールアドレス確認日時"
    t.datetime "confirmation_sent_at", comment: "メールアドレス確認送信日時"
    t.string "unconfirmed_email", comment: "確認待ちメールアドレス"
    t.integer "failed_attempts", default: 0, null: false, comment: "連続ログイン失敗回数"
    t.string "unlock_token", comment: "アカウントロック解除トークン"
    t.datetime "locked_at", comment: "アカウントロック日時"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["confirmation_token"], name: "index_admin_users3", unique: true
    t.index ["email"], name: "index_admin_users1", unique: true
    t.index ["reset_password_token"], name: "index_admin_users2", unique: true
    t.index ["unlock_token"], name: "index_admin_users4", unique: true
  end

  create_table "download_files", charset: "utf8", collation: "utf8_bin", comment: "ダウンロードファイル", force: :cascade do |t|
    t.bigint "download_id", null: false, comment: "ダウンロードID"
    t.binary "body", size: :long, comment: "内容"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["download_id"], name: "index_download_files_on_download_id"
  end

  create_table "downloads", charset: "utf8", collation: "utf8_bin", comment: "ダウンロード", force: :cascade do |t|
    t.bigint "user_id", null: false, comment: "ユーザーID"
    t.integer "status", default: 0, null: false, comment: "ステータス"
    t.datetime "requested_at", null: false, comment: "依頼日時"
    t.datetime "completed_at", comment: "完了日時"
    t.text "error_message", comment: "エラーメッセージ"
    t.datetime "last_downloaded_at", comment: "最終ダウンロード日時"
    t.integer "model", null: false, comment: "モデル"
    t.bigint "space_id", comment: "スペースID"
    t.integer "target", null: false, comment: "対象"
    t.integer "format", null: false, comment: "形式"
    t.integer "char_code", null: false, comment: "文字コード"
    t.integer "newline_code", null: false, comment: "改行コード"
    t.text "output_items", comment: "出力項目"
    t.text "select_items", comment: "選択項目"
    t.text "search_params", comment: "検索パラメータ"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["completed_at"], name: "index_downloads2"
    t.index ["space_id"], name: "index_downloads_on_space_id"
    t.index ["user_id", "requested_at"], name: "index_downloads1"
    t.index ["user_id"], name: "index_downloads_on_user_id"
  end

  create_table "holidays", charset: "utf8", collation: "utf8_bin", comment: "祝日", force: :cascade do |t|
    t.date "date", null: false, comment: "日付"
    t.string "name", null: false, comment: "名称"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["date"], name: "index_holidays1", unique: true
  end

  create_table "infomations", charset: "utf8", collation: "utf8_bin", comment: "お知らせ", force: :cascade do |t|
    t.string "title", null: false, comment: "タイトル"
    t.string "summary", comment: "概要"
    t.text "body", comment: "本文"
    t.datetime "started_at", null: false, comment: "開始日時"
    t.datetime "ended_at", comment: "終了日時"
    t.integer "target", null: false, comment: "対象"
    t.bigint "user_id", comment: "ユーザーID"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.integer "label", default: 0, null: false, comment: "ラベル"
    t.datetime "force_started_at", comment: "強制表示開始日時"
    t.datetime "force_ended_at", comment: "強制表示終了日時"
    t.index ["force_started_at", "force_ended_at"], name: "index_infomations4"
    t.index ["started_at", "ended_at"], name: "index_infomations2"
    t.index ["started_at", "id"], name: "index_infomations1"
    t.index ["target", "user_id"], name: "index_infomations3"
    t.index ["user_id"], name: "index_infomations_on_user_id"
  end

  create_table "invitations", charset: "utf8", collation: "utf8_bin", comment: "招待", force: :cascade do |t|
    t.string "code", null: false, comment: "コード"
    t.bigint "space_id", null: false, comment: "スペースID"
    t.string "email", comment: "メールアドレス"
    t.text "domains", comment: "ドメイン"
    t.integer "power", null: false, comment: "権限"
    t.string "memo", comment: "メモ"
    t.datetime "ended_at", comment: "終了日時"
    t.datetime "destroy_requested_at", comment: "削除依頼日時"
    t.datetime "destroy_schedule_at", comment: "削除予定日時"
    t.datetime "email_joined_at", comment: "参加日時"
    t.bigint "created_user_id", null: false, comment: "作成者ID"
    t.bigint "last_updated_user_id", comment: "最終更新者ID"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["code"], name: "index_invitations1", unique: true
    t.index ["created_at", "id"], name: "index_invitations6"
    t.index ["created_user_id"], name: "index_invitations_on_created_user_id"
    t.index ["destroy_schedule_at"], name: "index_invitations4"
    t.index ["email"], name: "index_invitations2"
    t.index ["email_joined_at"], name: "index_invitations5"
    t.index ["ended_at"], name: "index_invitations3"
    t.index ["last_updated_user_id"], name: "index_invitations_on_last_updated_user_id"
    t.index ["space_id"], name: "index_invitations_on_space_id"
  end

  create_table "members", charset: "utf8", collation: "utf8_bin", comment: "メンバー", force: :cascade do |t|
    t.bigint "space_id", null: false, comment: "スペースID"
    t.bigint "user_id", null: false, comment: "ユーザーID"
    t.integer "power", null: false, comment: "権限"
    t.bigint "invitationed_user_id", comment: "招待者ID"
    t.bigint "last_updated_user_id", comment: "最終更新者ID"
    t.datetime "invitationed_at", comment: "招待日時"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["created_at", "id"], name: "index_members6"
    t.index ["invitationed_at", "id"], name: "index_members5"
    t.index ["invitationed_user_id", "id"], name: "index_members3"
    t.index ["invitationed_user_id"], name: "index_members_on_invitationed_user_id"
    t.index ["last_updated_user_id", "id"], name: "index_members4"
    t.index ["last_updated_user_id"], name: "index_members_on_last_updated_user_id"
    t.index ["space_id", "power", "id"], name: "index_members2"
    t.index ["space_id", "user_id"], name: "index_members1", unique: true
    t.index ["space_id"], name: "index_members_on_space_id"
    t.index ["updated_at", "id"], name: "index_members7"
    t.index ["user_id"], name: "index_members_on_user_id"
  end

  create_table "spaces", charset: "utf8", collation: "utf8_bin", comment: "スペース", force: :cascade do |t|
    t.string "code", null: false, comment: "コード"
    t.string "image", comment: "画像"
    t.string "name", null: false, comment: "名称"
    t.text "description", comment: "説明"
    t.boolean "private", default: true, null: false, comment: "非公開"
    t.datetime "destroy_requested_at", comment: "削除依頼日時"
    t.datetime "destroy_schedule_at", comment: "削除予定日時"
    t.bigint "created_user_id", null: false, comment: "作成者ID"
    t.bigint "last_updated_user_id", comment: "最終更新者ID"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.integer "process_priority", default: 3, null: false, comment: "処理優先度"
    t.index ["code"], name: "index_spaces1", unique: true
    t.index ["created_at", "id"], name: "index_spaces3"
    t.index ["created_user_id"], name: "index_spaces_on_created_user_id"
    t.index ["destroy_schedule_at"], name: "index_spaces2"
    t.index ["last_updated_user_id"], name: "index_spaces_on_last_updated_user_id"
    t.index ["name", "id"], name: "index_spaces4"
    t.index ["process_priority", "id"], name: "index_spaces5"
  end

  create_table "task_cycles", charset: "utf8", collation: "utf8_bin", comment: "タスク周期", force: :cascade do |t|
    t.bigint "space_id", null: false, comment: "スペースID"
    t.bigint "task_id", null: false, comment: "タスクID"
    t.integer "cycle", null: false, comment: "周期"
    t.integer "month", comment: "月"
    t.integer "target", comment: "対象"
    t.integer "day", comment: "日"
    t.integer "business_day", comment: "営業日"
    t.integer "week", comment: "週"
    t.integer "wday", comment: "曜日"
    t.integer "handling_holiday", comment: "休日の扱い"
    t.integer "period", default: 1, null: false, comment: "期間（日）"
    t.datetime "deleted_at", comment: "削除日時"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["deleted_at", "id"], name: "index_task_cycles3"
    t.index ["space_id", "cycle", "month", "deleted_at"], name: "index_task_cycles1"
    t.index ["space_id"], name: "index_task_cycles_on_space_id"
    t.index ["task_id"], name: "index_task_cycles_on_task_id"
    t.index ["updated_at", "id"], name: "index_task_cycles2"
  end

  create_table "task_events", charset: "utf8", collation: "utf8_bin", comment: "タスクイベント", force: :cascade do |t|
    t.string "code", null: false, comment: "コード"
    t.bigint "space_id", null: false, comment: "スペースID"
    t.bigint "task_cycle_id", null: false, comment: "タスク周期ID"
    t.date "started_date", null: false, comment: "開始日"
    t.date "ended_date", null: false, comment: "終了日"
    t.integer "status", default: 0, null: false, comment: "ステータス"
    t.bigint "assigned_user_id", comment: "担当者ID"
    t.datetime "assigned_at", comment: "担当日時"
    t.text "memo", comment: "メモ"
    t.bigint "last_updated_user_id", comment: "最終更新者ID"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["assigned_user_id"], name: "index_task_events_on_assigned_user_id"
    t.index ["code"], name: "index_task_events1", unique: true
    t.index ["last_updated_user_id"], name: "index_task_events_on_last_updated_user_id"
    t.index ["space_id", "started_date", "ended_date"], name: "index_task_events3"
    t.index ["space_id"], name: "index_task_events_on_space_id"
    t.index ["task_cycle_id", "ended_date"], name: "index_task_events2", unique: true
    t.index ["task_cycle_id"], name: "index_task_events_on_task_cycle_id"
  end

  create_table "task_send_histories", charset: "utf8", collation: "utf8_bin", comment: "タスク通知履歴", force: :cascade do |t|
    t.bigint "space_id", null: false, comment: "スペースID"
    t.bigint "task_send_setting_id", null: false, comment: "タスク通知設定ID"
    t.integer "notice_target", null: false, comment: "通知対象"
    t.integer "send_target", null: false, comment: "送信対象"
    t.date "target_date", null: false, comment: "対象日"
    t.datetime "sended_at", null: false, comment: "送信日時"
    t.integer "send_result", null: false, comment: "送信結果"
    t.text "error_message", comment: "エラーメッセージ"
    t.text "sended_data", comment: "送信データ"
    t.text "next_task_event_ids", comment: "翌営業日開始のタスクイベントIDs"
    t.text "expired_task_event_ids", comment: "期限切れのタスクイベントIDs"
    t.text "end_today_task_event_ids", comment: "本日までのタスクイベントIDs"
    t.text "date_include_task_event_ids", comment: "期間内のタスクイベントIDs"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["space_id", "notice_target", "target_date", "id"], name: "task_send_histories1"
    t.index ["space_id"], name: "index_task_send_histories_on_space_id"
    t.index ["target_date", "sended_at", "id"], name: "task_send_histories2"
    t.index ["task_send_setting_id"], name: "index_task_send_histories_on_task_send_setting_id"
  end

  create_table "task_send_settings", charset: "utf8", collation: "utf8_bin", comment: "タスク通知設定", force: :cascade do |t|
    t.bigint "space_id", null: false, comment: "スペースID"
    t.boolean "slack_enabled", default: false, null: false, comment: "[Slack]通知する"
    t.string "slack_webhook_url", comment: "[Slack]Webhook URL"
    t.string "slack_mention", comment: "[Slack]メンション"
    t.boolean "email_enabled", default: false, null: false, comment: "[メール]通知する"
    t.string "email_address", comment: "[メール]アドレス"
    t.integer "today_notice_start_hour", comment: "[当日通知]開始時間"
    t.boolean "today_notice_required", default: false, null: false, comment: "[当日通知]必須"
    t.integer "next_notice_start_hour", comment: "[事前通知]開始時間"
    t.boolean "next_notice_required", default: false, null: false, comment: "[事前通知]必須"
    t.bigint "last_updated_user_id", comment: "最終更新者ID"
    t.datetime "deleted_at", comment: "削除日時"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["deleted_at", "id"], name: "task_send_settings3"
    t.index ["last_updated_user_id"], name: "index_task_send_settings_on_last_updated_user_id"
    t.index ["space_id", "deleted_at"], name: "task_send_settings1"
    t.index ["space_id"], name: "index_task_send_settings_on_space_id"
    t.index ["updated_at", "id"], name: "task_send_settings2"
  end

  create_table "tasks", charset: "utf8", collation: "utf8_bin", comment: "タスク", force: :cascade do |t|
    t.bigint "space_id", null: false, comment: "スペースID"
    t.integer "priority", default: 0, null: false, comment: "優先度"
    t.string "title", null: false, comment: "タイトル"
    t.text "summary", comment: "概要"
    t.text "premise", comment: "前提"
    t.text "process", comment: "手順"
    t.date "started_date", null: false, comment: "開始日"
    t.date "ended_date", comment: "終了日"
    t.bigint "created_user_id", null: false, comment: "作成者ID"
    t.bigint "last_updated_user_id", comment: "最終更新者ID"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["created_at", "id"], name: "index_tasks6"
    t.index ["created_user_id", "id"], name: "index_tasks4"
    t.index ["created_user_id"], name: "index_tasks_on_created_user_id"
    t.index ["last_updated_user_id", "id"], name: "index_tasks5"
    t.index ["last_updated_user_id"], name: "index_tasks_on_last_updated_user_id"
    t.index ["space_id", "ended_date"], name: "index_tasks3"
    t.index ["space_id", "priority"], name: "index_tasks1"
    t.index ["space_id", "started_date", "ended_date"], name: "index_tasks2"
    t.index ["space_id"], name: "index_tasks_on_space_id"
    t.index ["updated_at", "id"], name: "index_tasks7"
  end

  create_table "users", charset: "utf8", collation: "utf8_bin", comment: "ユーザー", force: :cascade do |t|
    t.string "code", null: false, comment: "コード"
    t.string "image", comment: "画像"
    t.string "name", null: false, comment: "氏名"
    t.string "email", default: "", null: false, comment: "メールアドレス"
    t.string "encrypted_password", default: "", null: false, comment: "暗号化されたパスワード"
    t.string "reset_password_token", comment: "パスワードリセットトークン"
    t.datetime "reset_password_sent_at", comment: "パスワードリセット送信日時"
    t.datetime "remember_created_at", comment: "ログイン状態維持開始日時"
    t.integer "sign_in_count", default: 0, null: false, comment: "ログイン回数"
    t.datetime "current_sign_in_at", comment: "現在のログイン日時"
    t.datetime "last_sign_in_at", comment: "最終ログイン日時"
    t.string "current_sign_in_ip", comment: "現在のログインIPアドレス"
    t.string "last_sign_in_ip", comment: "最終ログインIPアドレス"
    t.string "confirmation_token", comment: "メールアドレス確認トークン"
    t.datetime "confirmed_at", comment: "メールアドレス確認日時"
    t.datetime "confirmation_sent_at", comment: "メールアドレス確認送信日時"
    t.string "unconfirmed_email", comment: "確認待ちメールアドレス"
    t.integer "failed_attempts", default: 0, null: false, comment: "連続ログイン失敗回数"
    t.string "unlock_token", comment: "アカウントロック解除トークン"
    t.datetime "locked_at", comment: "アカウントロック日時"
    t.datetime "destroy_requested_at", comment: "削除依頼日時"
    t.datetime "destroy_schedule_at", comment: "削除予定日時"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "provider", default: "email", null: false, comment: "認証方法"
    t.string "uid", default: "", null: false, comment: "UID"
    t.boolean "allow_password_change", default: false, comment: "パスワード再設定中"
    t.text "tokens", comment: "認証トークン"
    t.datetime "infomation_check_last_started_at", comment: "お知らせ確認最終開始日時"
    t.index ["code"], name: "index_users5", unique: true
    t.index ["confirmation_token"], name: "index_users3", unique: true
    t.index ["destroy_schedule_at"], name: "index_users6"
    t.index ["email"], name: "index_users1", unique: true
    t.index ["reset_password_token"], name: "index_users2", unique: true
    t.index ["uid", "provider"], name: "index_users7", unique: true
    t.index ["unlock_token"], name: "index_users4", unique: true
  end

  create_table "versions", charset: "utf8", collation: "utf8_bin", force: :cascade do |t|
    t.string "item_type", null: false
    t.bigint "item_id", null: false
    t.string "event", null: false
    t.string "whodunnit"
    t.text "object", size: :long
    t.datetime "created_at"
    t.index ["item_type", "item_id"], name: "index_versions1"
  end

  add_foreign_key "download_files", "downloads"
  add_foreign_key "downloads", "users"
  add_foreign_key "infomations", "users"
  add_foreign_key "invitations", "spaces"
  add_foreign_key "members", "spaces"
  add_foreign_key "members", "users"
  add_foreign_key "task_cycles", "spaces"
  add_foreign_key "task_cycles", "tasks"
  add_foreign_key "task_events", "spaces"
  add_foreign_key "task_events", "task_cycles"
  add_foreign_key "task_send_histories", "spaces"
  add_foreign_key "task_send_histories", "task_send_settings"
  add_foreign_key "task_send_settings", "spaces"
  add_foreign_key "tasks", "spaces"
end
