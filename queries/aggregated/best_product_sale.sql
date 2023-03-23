SELECT
  product_name,
  RANK() OVER(
    ORDER BY
      SUM(quantity) DESC) AS rank_in_quantity,
  SUM(quantity) AS total_quantity,
  ROUND(SUM(quantity*unit_price),4) AS total_sales,
  RANK() OVER(
    ORDER BY
      SUM(quantity*unit_price) DESC) AS rank_in_sales,
FROM
  `sandbox-avestu.cleaned.basket_detail`
GROUP BY
  product_name