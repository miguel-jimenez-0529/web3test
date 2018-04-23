//
//  ViewController.swift
//  web3test
//
//  Created by Macbook Pro on 09/04/18.
//  Copyright © 2018 Macbook Pro. All rights reserved.
//

import UIKit
import web3
import web3swift

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        let button = UIButton(type: UIButtonType.contactAdd)
        
        view.addSubview(button)
        button.frame = CGRect(x: 200, y: 200, width: 200, height: 70)
        button.addTarget(self, action: #selector(self.getGas), for: UIControlEvents.touchUpInside)
    }
    
    @objc func getGas() {
//       let web3 = Web3.InfuraMainnetWeb3()
//        guard let balance = web3.eth.getBalance(address: EthereumAddress("0x005c1E464F8d4422e08B0620C7ADcdcBbe0FB240")).value else {
//            return
//        }
        let test  = Test.init()
        try! test.sendTransactionToSmartContract(passphrase: "", type: Test.SmartContractType.BBI, method: Test.SmartContractMethod.etherRaised, params: [])
        
        
        
    }

}
    

