//
//  DevicesVC.swift
//  SaneScanner
//
//  Created by Stanislas Chevallier on 03/02/2019.
//  Copyright © 2019 Syan. All rights reserved.
//

import UIKit
import SaneSwift
import DLAlertView
import SVProgressHUD
import SYKit

class DevicesVC: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .groupTableViewBackground
        
        thumbsView = GalleryThumbsView.showInToolbar(of: self, tintColor: nil)
        
        tableView.registerCell(HostCell.self, xib: true)
        tableView.registerCell(DeviceCell.self, xib: true)
        tableView.sy_addPullToResfresh { [weak self] (_) in
            self?.refreshDevices()
        }
        
        navigationItem.rightBarButtonItem = PreferencesVC.settingsBarButtonItem(target: self, action: #selector(self.settingsButtonTap))
        
        Sane.shared.delegate = self
        
        sy_setBackButton(withText: nil, font: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        title = Bundle.main.localizedName
        tableView.reloadData()
        
        if devices.isEmpty {
            refreshDevices()
        }
    }
    
    // MARK: Views
    @IBOutlet private var tableView: UITableView!
    private var thumbsView: GalleryThumbsView!
    
    // MARK: Properties
    private var devices = [Device]()
    
    // MARK: Actions
    @objc private func settingsButtonTap() {
        let nc = UINavigationController(rootViewController: PreferencesVC())
        nc.modalPresentationStyle = .formSheet
        present(nc, animated: true, completion: nil)

    }
    
    private func refreshDevices() {
        Sane.shared.updateDevices { [weak self] (devices, error) in
            guard let self = self else { return }
            self.devices = devices ?? []
            self.tableView.reloadData()
            
            // in case it was opened (e.g. for screenshots)
            SVProgressHUD.dismiss()

            if let error = error {
                SVProgressHUD.showError(withStatus: error.localizedDescription)
            }
        }
    }
    
    private func addHostButtonTap() {
        let av = DLAVAlertView(
            title: "DIALOG TITLE ADD HOST".localized,
            message: "DIALOG MESSAGE ADD HOST".localized,
            delegate: nil,
            cancel: "ACTION CANCEL".localized,
            others: ["ACTION ADD".localized]
        )
        
        av.alertViewStyle = .plainTextInput
        av.textField(at: 0)?.borderStyle = .none
        av.textField(at: 0)?.autocorrectionType = .no
        av.textField(at: 0)?.autocapitalizationType = .none
        av.textField(at: 0)?.keyboardType = .URL
        av.show { (alert, index) in
            guard index != alert?.cancelButtonIndex else { return }
            let host = av.textField(at: 0)?.text ?? ""
            Sane.shared.configuration.addHost(host)
            self.tableView.reloadData()
            self.refreshDevices()
        }
    }
}

extension DevicesVC: SaneDelegate {
    func saneDidStartUpdatingDevices(_ sane: Sane) {
        tableView.sy_showPullToRefresh()
    }
    
    func saneDidEndUpdatingDevices(_ sane: Sane) {
        tableView.sy_endPullToRefresh()
    }
    
    func saneNeedsAuth(_ sane: Sane, for device: String?, completion: @escaping (DeviceAuthentication?) -> ()) {
        let alertView = DLAVAlertView(
            title: "DIALOG TITLE AUTH".localized,
            message: String(format: "DIALOG MESSAGE AUTH %@".localized, device ?? "unknown"),
            delegate: nil,
            cancel: "ACTION CANCEL".localized,
            others: ["ACTION CONTINUE".localized]
        )
        
        alertView.alertViewStyle = .loginAndPasswordInput
        alertView.textField(at: 0)?.borderStyle = .none
        alertView.textField(at: 1)?.borderStyle = .none
        alertView.show { (alert, index) in
            guard alert?.cancelButtonIndex != index else {
                completion(nil)
                return
            }
            completion(DeviceAuthentication(username: alert?.textField(at: 0)?.text, password: alert?.textField(at: 1)?.text))
        }
    }
}

extension DevicesVC : UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0 ? Sane.shared.configuration.hosts.count + 1 : devices.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueCell(HostCell.self, for: indexPath)
            if indexPath.row < Sane.shared.configuration.hosts.count {
                cell.title = Sane.shared.configuration.hosts[indexPath.row]
                cell.showAddIndicator = false
            }
            else {
                cell.title = "DEVICES ROW ADD HOST".localized
                cell.showAddIndicator = true
            }
            return cell
        }
        
        let cell = tableView.dequeueCell(DeviceCell.self, for: indexPath)
        cell.device = devices[indexPath.row]
        return cell
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return section == 0 ? "DEVICES SECTION HOSTS".localized : "DEVICES SECTION DEVICES".localized;
    }
}

extension DevicesVC : UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
    
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        guard indexPath.section == 0 else { return nil }
        guard indexPath.row < Sane.shared.configuration.hosts.count else { return nil }
        
        let deleteAction = UITableViewRowAction(style: .destructive, title: "ACTION REMOVE".localized) { (_, indexPath) in
            Sane.shared.configuration.removeHost(Sane.shared.configuration.hosts[indexPath.row])
            
            CATransaction.begin()
            CATransaction.setCompletionBlock {
                self.refreshDevices()
            }
            tableView.beginUpdates()
            tableView.deleteRows(at: [indexPath], with: .bottom)
            tableView.endUpdates()
            CATransaction.commit()
        }
        return [deleteAction]
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        if indexPath.section == 0 {
            guard indexPath.row >= Sane.shared.configuration.hosts.count else { return }
            addHostButtonTap()
            return
        }
        
        let device = devices[indexPath.row]
        SVProgressHUD.show(withStatus: "LOADING".localized)
        
        Sane.shared.openDevice(device) { (error) in
            if AppDelegate.obtain.snapshotType == .none {
                SVProgressHUD.dismiss()
            }
            
            if let error = error {
                let alert = UIAlertController(
                    title: "DIALOG TITLE COULDNT OPEN DEVICE".localized,
                    message: error.localizedDescription,
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "ACTION CLOSE".localized, style: .default, handler: nil))
                self.present(alert, animated: true, completion: nil)
                return
            }
            let vc = DeviceVC(device: device)
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }
}
