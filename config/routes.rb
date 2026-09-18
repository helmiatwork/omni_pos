Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root to: "pos#sell"

  get "/sell" => "pos#sell", as: :sell

  get "/orders" => "orders#index", as: :orders
  post "/orders" => "orders#create"
  post "/orders/:id/fulfill" => "orders#fulfill", as: :fulfill_order
  post "/orders/:id/complete" => "orders#complete", as: :complete_order
  post "/orders/:id/void" => "orders#void", as: :void_order
  post "/orders/:id/tenders" => "tenders#create", as: :order_tenders

  get "/shifts" => "shifts#index", as: :shifts
  post "/shifts/open" => "shifts#open", as: :open_shift
  post "/shifts/:id/close" => "shifts#close", as: :close_shift

  get "/pad" => "pad#show", as: :pad
end
