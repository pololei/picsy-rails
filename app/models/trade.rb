# 取引／Trade
#
# 経済主体Aと経済主体Bとの間で、商品と評価を交換すること。
#
class Trade < ActiveRecord::Base
  # 取引は商品を買う経済主体に属する
  belongs_to :buyable, :polymorphic => true

  # 取引は商品を売る経済主体に属する
  belongs_to :sellable, :polymorphic => true

  # 取引は一つの商品からなる
  belongs_to :item

  # 取引は一つの評価をもつ
end
