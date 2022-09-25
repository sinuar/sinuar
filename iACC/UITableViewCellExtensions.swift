//	
// Copyright © Essential Developer. All rights reserved.
//

import UIKit

extension UITableViewCell {
   func configure(_ vm: ItemViewModel) {
      textLabel?.text = vm.title
      detailTextLabel?.text = vm.subtitle
   }
}
