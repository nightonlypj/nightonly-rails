json.success true
json.send_history do
  json.partial! 'send_history', send_history: @send_history, detail: true
end
