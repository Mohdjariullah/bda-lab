// Connect and Create/Switch Database
use store_db;

// 1. CREATE (Insert Documents with Embedded Arrays)
db.products.insertMany([
  {
    _id: 1,
    item: "Laptop",
    price: 1200,
    tags: ["electronics", "computers", "tech"],
    ratings: [5, 4, 5]
  },
  {
    _id: 2,
    item: "Mouse",
    price: 25,
    tags: ["electronics", "accessories"],
    ratings: [3, 4]
  }
]);

// 2. READ (Find Query with Array Filter)
db.products.find({ tags: "tech" }).pretty();

// 3. UPDATE (Modify Array - Append new tag & update price)
db.products.updateOne(
  { _id: 1 },
  {
    $set: { price: 1150 },
    $push: { tags: "sale" }
  }
);

// 4. ARRAY AGGREGATION & UNWINDING
db.products.aggregate([
  { $unwind: "$tags" },
  { $group: { _id: "$tags", count: { $sum: 1 } } }
]);

// 5. DELETE
db.products.deleteOne({ _id: 2 });
