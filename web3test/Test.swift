import BigInt
import web3swift

class Test {
    
    private enum File: String {
        case KeyStore
    }
    private enum PrivateKeyFormat {
        case Base10
        case Base16
        case Error
    }
    private enum PrivateKeyError: Error {
        case InvalidPrivateKey
    }
    public enum SmartContractType {
        case BBI
    }
    public enum SmartContractMethod: String {
        case etherRaised = "etherRaised"
    }
    public enum SmartContractError: Error {
        case InvalidMethod
        case SmartContractFailure
        case TransactionSigningFailure
        case TXHashReceiveFailure
        case Web3ProviderNotFound
    }
    
    // Crear y/o obtener la ruta del directorio donde se guardará el JSON v3.
    private func getFilePath(_ type: File) -> String {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let folder = url.appendingPathComponent(type.rawValue)
        
        if !FileManager.default.fileExists(atPath: folder.path) {
            try! FileManager.default.createDirectory(atPath: folder.path, withIntermediateDirectories: true, attributes: nil)
        }
        
        switch type {
        case .KeyStore:
            return folder.path
        }
    }
    
    // Función para manejar un número en decimal y convertirlo en hexadecimal, o en caso de ya ser un hexadecimal, validar si cumple con el tamaño de una address de ETH.
    // Nota: Eliminar el "0x" del string de la private key antes de pasarlo a esta función.
    private func getPrivateKeyFormat(_ privateKey: String) -> PrivateKeyFormat {
        var isHex = false
        var token: PrivateKeyFormat!
        
        for character in privateKey.lowercased() {
            switch String(character) {
            case "0", "1", "2", "3", "4", "5", "6", "7", "8", "9":
                if !isHex {
                    token = .Base10
                }
            case "a", "b", "c", "d", "e", "f":
                token = .Base16
                isHex = true
            default:
                return .Error
            }
        }
        
        return token
    }
    
    // Obtener el KeyStore Manager, el cual permite firmar las transacciones junto con el passphrase, además de ser necesario para otras funciones.
    private func getKeyStoreManager() -> KeystoreManager {
        let path = self.getFilePath(.KeyStore)
        let keystoreManager = KeystoreManager.managerForPath(path)!
        
        return keystoreManager
    }
    
    // Checar si existe ya una o más cuentas.
    private func isThereAnAccount() -> Bool {
        let keystoreManager = self.getKeyStoreManager()
        
        return keystoreManager.addresses!.count > 0
    }
    
    // Creación de la cuenta, el nombre del archivo JSON puede cualquiera.
    private func createAccount(_ passphrase: String) {
        do {
            let newAccount = try EthereumKeystoreV3(password: passphrase)
            let jsonv3 = try JSONEncoder().encode(newAccount!.keystoreParams)
            let path = self.getFilePath(.KeyStore)
            
            FileManager.default.createFile(atPath: "\(path)/Account.json", contents: jsonv3, attributes: nil)
        }
        catch {
            print("Error trying to create the account: \(error.localizedDescription)")
        }
    }
    
    // Importación de la cuenta, es obligatorio pasar una passphrase para poder crear el archivo JSON v3, en caso de omitirlo puede importarse la cuenta sólo con la private key, pero la firma deberá realizarse con la misma private key (siendo está convertida de "String" a "Data") y deberá crearse algún método para mantener esta llave protegida.
    private func importAccount(_ privateKey: String, _ passphrase: String) {
        do {
            var privateKeyData = Data()
            
            switch self.getPrivateKeyFormat(privateKey) {
            case .Base10:
                let base10 = BigUInt(stringLiteral: privateKey)
                let base16 = String(base10, radix: 16)
                
                if base16.count != 64 {
                    throw PrivateKeyError.InvalidPrivateKey
                }
                
                privateKeyData = Data.fromHex(base16)!
            case .Base16:
                if privateKey.count != 64 {
                    throw PrivateKeyError.InvalidPrivateKey
                }
                
                privateKeyData = Data.fromHex(privateKey)!
            case .Error:
                throw PrivateKeyError.InvalidPrivateKey
            }
            
            let path = self.getFilePath(.KeyStore)
            let importedAccount = try EthereumKeystoreV3.init(privateKey: privateKeyData, password: passphrase)//.init(privateKey: privateKeyData)
            let jsonv3 = try JSONEncoder().encode(importedAccount!.keystoreParams)
            
            FileManager.default.createFile(atPath: "\(path)/Account.json", contents: jsonv3, attributes: nil)
        }
        catch {
            print("Error trying to import the account: \(error.localizedDescription)")
        }
    }
    
    // Obtener la address de la cuenta.
    private func getAccountAddress() -> EthereumAddress {
        let keystoreManager = self.getKeyStoreManager()
        
        return keystoreManager.addresses!.first!
    }
    
    // Obtener la private key de la cuenta, siempre y cuando se haya decidido crear el archivo JSON v3 (esto en el caso de importar la cuenta).
    private func getAccountPrivateKey(_ passphrase: String) throws -> String {
        let accountAddress = self.getAccountAddress()
        let keystoreManager = self.getKeyStoreManager()
        let privateKeyData = try keystoreManager.UNSAFE_getPrivateKeyData(password: passphrase, account: accountAddress)
        
        return privateKeyData.bytes.toHexString()
    }
    
    // Función para obtener el archivo JSON que contenga el ABI del smart contract y su respectiva address. Es obligatorio añadir a la app el archivo JSON con el ABI o al menos el string completo de dicho ABI resguardado en una constante de tipo String.
    private func getSmartContractParams(_ type: SmartContractType) -> (abi : String, address: String) {
        var json = String()
        var address = String()
        
        switch type {
        case .BBI:
            json = "bbi"
            address = "0x37D40510a2F5Bc98AA7a0f7BF4b3453Bcfb90Ac1"
        }
        
        let path = Bundle.main.path(forResource: json, ofType: "json")!
        let abi = try! String(contentsOf: URL(fileURLWithPath: path))
        
        return (abi, address)
    }
    
    // Función que firma y manda una transacción a un smart contract.
    // Nota: Aún no se ha probado para realizar firma de transacciones cuando son transferencias entre cuentas, para eso checar el único ejemplo que tiene la librería.
    public func sendTransactionToSmartContract(passphrase: String, type: SmartContractType, method: SmartContractMethod, params: [AnyObject]) throws -> String {
        guard let url = URL(string: "https://mainnet.infura.io"), let web3 = Web3.new(url) else {
            throw SmartContractError.Web3ProviderNotFound
        }
        
        let keystoreManager = self.getKeyStoreManager()
        let smartcontractABI = self.getSmartContractParams(type).abi
        let smartcontractAddress = EthereumAddress(self.getSmartContractParams(type).address)
        var options = Web3Options()
        
        web3.addKeystoreManager(keystoreManager)
        
        options.from = EthereumAddress.init("0x005c1E464F8d4422e08B0620C7ADcdcBbe0FB240")//self.getAccountAddress()
        options.gasPrice = BigUInt(0)
        options.gasLimit = BigUInt(0)
        
        guard let smartcontract = web3.contract(smartcontractABI, at: smartcontractAddress) else {
            throw SmartContractError.SmartContractFailure
        }
       /*guard let intermediate = smartcontract.method(method.rawValue, parameters: params, options: options) else {
            throw SmartContractError.InvalidMethod
        }*/
        let intermediate = smartcontract.method(method.rawValue, options: options)
        let result =  intermediate?.call(options: options)
        result?.analysis(ifSuccess: { (values) in
            if  let intValue = values["0"] as? BigUInt,
                let ether = Web3.Utils.formatToEthereumUnits(intValue, toUnits: Web3.Utils.Units.eth, decimals: 2) {
                    print(ether)
            }
        }, ifFailure: { (error) in
            print(error)
        })
        return ""
//        intermediate.transaction.nonce = web3.eth.getTransactionCount(address: self.getAccountAddress()).value!
//
//        guard web3.wallet.signTX(transaction: &intermediate.transaction, account: self.getAccountAddress(), password: passphrase).value! else {
//            throw SmartContractError.TransactionSigningFailure
//        }
//        guard let result = intermediate.sendSigned().value else {
//            throw SmartContractError.TXHashReceiveFailure
//        }
//
//        return result["txhash"]!
    }
    
}

