//	
// Copyright © Essential Developer. All rights reserved.
//

import UIKit

class MainTabBarController: UITabBarController {
   
   private var friendsCache: FriendsCache!
   
   convenience init(friendsCache: FriendsCache) {
      self.init(nibName: nil, bundle: nil)
      self.friendsCache = friendsCache
      self.setupViewController()
   }
   
   private func setupViewController() {
      viewControllers = [
         makeNav(for: makeFriendsList(), title: "Friends", icon: "person.2.fill"),
         makeTransfersList(),
         makeNav(for: makeCardsList(), title: "Cards", icon: "creditcard.fill")
      ] }
   
   private func makeNav(for vc: UIViewController, title: String, icon: String) -> UIViewController {
      vc.navigationItem.largeTitleDisplayMode = .always
      
      let nav = UINavigationController(rootViewController: vc)
      nav.tabBarItem.image = UIImage(
         systemName: icon,
         withConfiguration: UIImage.SymbolConfiguration(scale: .large)
      )
      nav.tabBarItem.title = title
      nav.navigationBar.prefersLargeTitles = true
      return nav
   }
   
   private func makeTransfersList() -> UIViewController {
      let sent = makeSentTransfersList()
      sent.navigationItem.title = "Sent"
      sent.navigationItem.largeTitleDisplayMode = .always
      
      let received = makeReceivedTransfersList()
      received.navigationItem.title = "Received"
      received.navigationItem.largeTitleDisplayMode = .always
      
      let vc = SegmentNavigationViewController(first: sent, second: received)
      vc.tabBarItem.image = UIImage(
         systemName: "arrow.left.arrow.right",
         withConfiguration: UIImage.SymbolConfiguration(scale: .large)
      )
      vc.title = "Transfers"
      vc.navigationBar.prefersLargeTitles = true
      return vc
   }
   
   private func makeFriendsList() -> ListViewController {
      let vc = ListViewController()
      vc.title = "Friends"
      vc.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem:
            .add, target: vc, action: #selector(addFriend))
      
      let isPremium = User.shared?.isPremium == true
      
      let api = FriendsAPIItemsServiceAdapter(
         select: { [weak vc] item in
            vc?.select(friend: item)
         },
         api: FriendsAPI.shared,
         cache: isPremium ? friendsCache: NullFriendsCache()
      ).retry(2)
      
      let cache = FriendsCacheItemsServiceAdapter(
         select: { [weak vc] item in
            vc?.select(friend: item)
         },
         cache: friendsCache)
      
      vc.service = isPremium ? api.fallback(cache): api
      
      return vc
   }
   
   private func makeSentTransfersList() -> ListViewController {
      let vc = ListViewController()
      
      vc.navigationItem.title = "Sent"
      vc.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Send", style:
            .done, target: vc, action: #selector(sendMoney))
      
      vc.service = SentTransfersAPIItemsServiceAdapter(
         select: { [weak vc] item in
            vc?.select(transfer: item)
         },
         api: TransfersAPI.shared
      ).retry(1)
      
      return vc
   }
   
   private func makeReceivedTransfersList() -> ListViewController {
      let vc = ListViewController()
      
      vc.navigationItem.title = "Received"
      vc.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Request", style:
            .done, target: vc, action: #selector(requestMoney))
      vc.service = ReceivedTransfersAPIItemsServiceAdapter(
         select: { [weak vc] item in
            vc?.select(transfer: item)
         },
         api: TransfersAPI.shared
      ).retry(1)
      
      return vc
   }
   
   private func makeCardsList() -> ListViewController {
      let vc = ListViewController()
      vc.title = "Cards"
      vc.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem:
            .add, target: vc, action: #selector(addCard))
      vc.service = CardAPIItemsServiceAdapter(
         select: {[weak vc] item in
            vc?.select(card: item)
         },
         api: CardAPI.shared)
      return vc
   }
}

extension ItemsService {
   func fallback(_ fallback: ItemsService) -> ItemsService {
      ItemsServiceWithFallback(primary: self, fallback: fallback)
   }
   
   func retry(_ retryCount: UInt) -> ItemsService {
      var service: ItemsService = self
      for _ in 0..<retryCount {
         service = service.fallback(self)
      }
      return service
   }
}

struct ItemsServiceWithFallback: ItemsService {
   let primary: ItemsService
   let fallback: ItemsService
   
   func loadItems(completion: @escaping (Result<[ItemViewModel], Error>) -> Void) {
      primary.loadItems { result in
         switch result {
            case .success:
               completion(result)
            case .failure:
               fallback.loadItems(completion: completion)
               
         }
      }
   }
}

struct FriendsAPIItemsServiceAdapter: ItemsService {
   let select: (Friend) -> Void
   let api: FriendsAPI
   let cache: FriendsCache
   
   func loadItems(completion: @escaping (Result<[ItemViewModel], Error>) -> Void) {
      api.loadFriends { result in
         DispatchQueue.mainAsyncIfNeeded {
            completion(result.map { items in
               cache.save(items)
               
               return items.map { item in
                  ItemViewModel(friend: item, selection: {
                     select(item)
                  })
               }
            })
         }
      }
   }
}

struct FriendsCacheItemsServiceAdapter: ItemsService {
   let select: (Friend) -> Void
   let cache: FriendsCache
   
   func loadItems(completion: @escaping (Result<[ItemViewModel], Error>) -> Void) {
      cache.loadFriends { result in
         DispatchQueue.mainAsyncIfNeeded {
            completion(result.map { items in
               items.map { item in
                  ItemViewModel(friend: item, selection: {
                     select(item)
                  })
               }
            })
         }
      }
   }
}

// Null Object Pattern
class NullFriendsCache: FriendsCache {
   override func save(_ newFriends: [Friend]) {}
}

struct CardAPIItemsServiceAdapter: ItemsService {
   let select: (Card) -> Void
   let api: CardAPI
   
   func loadItems(completion: @escaping (Result<[ItemViewModel], Error>) -> Void) {
      api.loadCards { result in
         DispatchQueue.mainAsyncIfNeeded {
            completion(result.map { items in
               items.map { item in
                  ItemViewModel(card: item, selection: {
                     select(item)
                  })
               }
            })
         }
      }
   }
}

struct SentTransfersAPIItemsServiceAdapter: ItemsService {
   let select: (Transfer) -> Void
   let api: TransfersAPI
   
   func loadItems(completion: @escaping (Result<[ItemViewModel], Error>) -> Void) {
      api.loadTransfers { result in
         DispatchQueue.mainAsyncIfNeeded {
            completion(result.map { items in
               items
                  .filter { $0.isSender}
                  .map { item in
                     ItemViewModel(
                        transfer: item,
                        longDateStyle: true,
                        selection: {
                           select(item)
                        })
                  }
            })
         }
      }
   }
}

struct ReceivedTransfersAPIItemsServiceAdapter: ItemsService {
   let select: (Transfer) -> Void
   let api: TransfersAPI
   
   func loadItems(completion: @escaping (Result<[ItemViewModel], Error>) -> Void) {
      api.loadTransfers { result in
         DispatchQueue.mainAsyncIfNeeded {
            completion(result.map { items in
               items
                  .filter { !$0.isSender}
                  .map { item in
                     ItemViewModel(
                        transfer: item,
                        longDateStyle: false,
                        selection: {
                           select(item)
                        })
                  }
            })
         }
      }
   }
}
