import Foundation

/// Reusable GraphQL fragments. Each document appends only the fragments it uses
/// (GraphQL rejects documents that declare unused fragments).
enum GraphQLFragments {
    static let userFields = """
    fragment UserFields on User {
      id
      username
      email
      firstName
      lastName
      fullName
      gender
      image
    }
    """

    static let productCard = """
    fragment ProductCard on Product {
      id
      title
      price
      finalPrice
      discountPercentage
      rating
      stock
      thumbnail
      category
      brand
      availabilityStatus
    }
    """

    static let productDetail = """
    fragment ProductDetail on Product {
      description
      tags
      images
      sku
      weight
      warrantyInformation
      shippingInformation
      returnPolicy
      minimumOrderQuantity
      dimensions { width height depth }
      reviews { rating comment date reviewerName }
    }
    """

    static let cartFields = """
    fragment CartFields on Cart {
      id
      userId
      total
      discountedTotal
      totalProducts
      totalQuantity
      isLocal
      updatedAt
      items {
        productId
        title
        price
        quantity
        total
        discountPercentage
        finalPrice
        discountedTotal
        thumbnail
        product { id brand category stock availabilityStatus }
      }
    }
    """

    static let syncFields = """
    fragment SyncFields on SyncResult {
      entity
      count
      syncedAt
    }
    """
}
