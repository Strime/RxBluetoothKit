import CoreBluetooth
import RxBluetoothKit
import RxSwift
import UIKit

class CentralSpecificViewController: UIViewController {

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    // MARK: - View

    private(set) lazy var centralSpecificView = CentralSpecificView()

    override func loadView() {
        view = centralSpecificView
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        centralSpecificView.readValueLabel.isEnabled = false
        centralSpecificView.connectButton.addTarget(self, action: #selector(handleConnectButton), for: .touchUpInside)
    }

    // MARK: - Private

    private let disposeBag = DisposeBag()
    private lazy var manager = CentralManager()

    @objc private func handleConnectButton() {
        guard let serviceUuidString = centralSpecificView.serviceUuidTextField.text,
              let characteristicUuidString = centralSpecificView.characteristicUuidTextField.text else { return }

        let serviceUuid = CBUUID(string: serviceUuidString)
        let characteristicUuid = CBUUID(string: characteristicUuidString)

        scanAndConnect(serviceUuid: serviceUuid, characteristicUuid: characteristicUuid)
    }

    private func scanAndConnect(serviceUuid: CBUUID, characteristicUuid: CBUUID) {
        let managerIsOn = manager.observeStateWithInitialValue()
            .filter { $0 == .poweredOn }
            .map { _ in }

        Observable.combineLatest(managerIsOn, Observable.just(manager)) { $1 }
            .flatMap { $0.scanForPeripherals(withServices: [serviceUuid]) }
            .timeout(.seconds(7), scheduler: MainScheduler.instance)
            .take(1)
            .flatMap { $0.peripheral.establishConnection() }
            .do(onNext: { [weak self] _ in self?.centralSpecificView.readValueLabel.isEnabled = true })
            .flatMap { $0.discoverServices([serviceUuid]) }
            .flatMap { Observable.from($0) }
            .flatMap { $0.discoverCharacteristics([characteristicUuid]) }
            .flatMap { Observable.from($0) }
            .flatMap { $0.observeValueUpdateAndSetNotification() }
            .subscribe(
                onNext: { [weak self] in
                    guard let data = $0.value, let string = String(data: data, encoding: .utf8) else { return }
                    self?.updateValue(string)
                },
                onError: { [weak self] in
                    AlertPresenter.presentError(with: $0.localizedDescription, on: self?.navigationController)
                }
            )
            .disposed(by: disposeBag)
    }

    private func updateValue(_ value: String) {
        centralSpecificView.readValueLabel.text = "Read value: " + value
    }

}