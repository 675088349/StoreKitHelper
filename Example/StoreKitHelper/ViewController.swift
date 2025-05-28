//
//  ViewController.swift
//  StoreKitHelper
//
//  Created by RicoLu on 05/27/2025.
//  Copyright (c) 2025 RicoLu. All rights reserved.
//

import UIKit
import StoreKitHelper

class ViewController: UIViewController {
    let store = StoreService(productIds: ["RC_IOS_year_1", "RC_IOS_week_2", "RC_IOS_month_1"])
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        Task {
            try await store.restorePurchases()
//            let list = try await store.getProducts()
//            if let first = list.first {
//                let result = try await store.purchase(first)
//                let one = result.0
//                let two = result.1
//                print("")
//            }
        }
    }
}

