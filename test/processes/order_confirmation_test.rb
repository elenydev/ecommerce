require 'test_helper'

class OrderConfirmationTest < ActiveSupport::TestCase

  cover 'OrderConfirmation'

  def test_authorized_is_not_enough_to_confirm
    product_uid = SecureRandom.uuid
    product_id = run_command(ProductCatalog::RegisterProduct.new(product_uid: product_uid, name: "Async Remote"))
    run_command(Pricing::SetPrice.new(product_id: product_id, price: 39))
    customer = Customer.create(name: 'test')
    [
      Pricing::AddItemToBasket.new(order_id: order_id, product_id: product_id),
      Ordering::SubmitOrder.new(order_id: order_id, customer_id: customer.id),
      Payments::AuthorizePayment.new(transaction_id: transaction_id, order_id: order_id)
    ].each do |cmd|
      Rails.configuration.command_bus.call(cmd)
    end
    assert_equal("Submitted", Orders::Order.find_by_uid(order_id).state)
  end

  def test_payment_confirms_order
    product_uid = SecureRandom.uuid
    product_id = run_command(ProductCatalog::RegisterProduct.new(product_uid: product_uid, name: "Async Remote"))
    run_command(Pricing::SetPrice.new(product_id: product_id, price: 39))

    customer = Customer.create(name: 'test')
    [
      Pricing::AddItemToBasket.new(order_id: order_id, product_id: product_id),
      Ordering::SubmitOrder.new(order_id: order_id, customer_id: customer.id),
      Payments::AuthorizePayment.new(transaction_id: transaction_id, order_id: order_id),
      Payments::CapturePayment.new(transaction_id: transaction_id)
    ].each do |cmd|
      Rails.configuration.command_bus.call(cmd)
    end
    assert_equal("Ready to ship (paid)", Orders::Order.find_by_uid(order_id).state)
  end

  def transaction_id
    @transaction_id ||= SecureRandom.hex(16)
  end

  def order_id
    @order_id ||= SecureRandom.uuid
  end

end
