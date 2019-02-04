//
//  PreferencesVC.swift
//  SaneScanner
//
//  Created by Stanislas Chevallier on 03/02/2019.
//  Copyright © 2019 Syan. All rights reserved.
//

import UIKit
import SYKit
import SYEmailHelper

@objc class PreferencesVC: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "PREFERENCES TITLE".localized
        view.backgroundColor = .groupTableViewBackground
        
        tableView.registerCell(OptionCell.self, xib: true)
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .stop, target: self, action: #selector(self.closeButtonTap))
    }

    @objc static func settingsBarButtonItem(target: Any, action: Selector) -> UIBarButtonItem {
        return UIBarButtonItem(image: UIImage(named: "settings"), style: .plain, target: target, action: action)
    }

    // MARK: Properties
    private static let contactEmailAddress = "contact@syan.me"

    // MARK: Views:
    @IBOutlet private var tableView: UITableView!
    
    // MARK: Actions
    @objc private func closeButtonTap() {
        dismiss(animated: true, completion: nil)
    }
}

extension PreferencesVC : UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return Preferences.shared.groupedKeys.count + 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section < Preferences.shared.groupedKeys.count {
            return Preferences.shared.groupedKeys[section].1.count
        }
        return 2
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueCell(OptionCell.self, for: indexPath)
        if indexPath.section < Preferences.shared.groupedKeys.count {
            let prefKey = Preferences.shared.groupedKeys[indexPath.section].1[indexPath.row]
            cell.updateWith(prefKey: prefKey)
            cell.showDescription = true
        }
        else {
            if indexPath.row == 0 {
                cell.updateWith(leftText: "PREFERENCES TITLE CONTACT".localized, rightText: PreferencesVC.contactEmailAddress)
            }
            else {
                cell.updateWith(leftText: "PREFERENCES TITLE VERSION".localized, rightText: UIApplication.sy_appVersionAndBuild())
            }
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section < Preferences.shared.groupedKeys.count {
            return Preferences.shared.groupedKeys[section].0
        }
        return "PREFERENCES SECTION ABOUT APP"
    }
}

extension PreferencesVC : UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section < Preferences.shared.groupedKeys.count {
            let prefKey = Preferences.shared.groupedKeys[indexPath.section].1[indexPath.row]
            return OptionCell.cellHeight(prefKey: prefKey, showDescription: true, width: tableView.bounds.width)
        }
        if indexPath.row == 0 {
            return OptionCell.cellHeight(leftText: "PREFERENCES TITLE CONTACT".localized, rightText: PreferencesVC.contactEmailAddress, width: tableView.bounds.width)
        }
        else {
            return OptionCell.cellHeight(leftText: "PREFERENCES TITLE VERSION".localized, rightText: UIApplication.sy_appVersionAndBuild(), width: tableView.bounds.width)
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        // ABOUT APP section
        if indexPath.section >= Preferences.shared.groupedKeys.count {
            guard indexPath.row == 0 else { return }
            
            // TODO: cleanup
            var subject = String(format: "CONTACT SUBJECT ABOUT APP %@".localized, UIApplication.shared.sy_localizedName())
            subject += " " + UIApplication.sy_appVersionAndBuild()
            
            SYEmailServicePasteboard.name = "MAIL COPY PASTEBOARD NAME".localized
            SYEmailHelper.shared()?.composeEmail(
                withAddress: PreferencesVC.contactEmailAddress,
                subject: subject,
                body: nil,
                presentingVC: self) { (launched, service, error) in
                    // TODO: show HUD for pasteboard
                    print("Completion:", service?.name ?? "<no service>", launched, error?.localizedDescription ?? "<no error>")
            }
            return
        }
        
        let prefKey = Preferences.shared.groupedKeys[indexPath.section].1[indexPath.row]
        let previousValue = Preferences.shared.value(for: prefKey)
        Preferences.shared.setValue(!previousValue, for: prefKey)
        
        tableView.beginUpdates()
        tableView.reloadRows(at: [indexPath], with: .automatic)
        tableView.endUpdates()
    }
}