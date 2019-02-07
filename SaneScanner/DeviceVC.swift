//
//  DeviceVC.swift
//  SaneScanner
//
//  Created by Stanislas Chevallier on 04/02/2019.
//  Copyright © 2019 Syan. All rights reserved.
//

import UIKit
import SVProgressHUD
import SaneSwift
import SYKit
import SYPictureMetadata
import MHVideoPhotoGallery

class DeviceVC: UIViewController {

    init(device: SYSaneDevice) {
        self.device = device
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .groupTableViewBackground
        title = device.model

        // TODO: cleanup
        // can't reenable swipe back because we wouldn't get the possiblity to close the device once it's not needed
        //navigationController?.interactivePopGestureRecognizer?.delegate = nil
        
        tableView.registerCell(PreviewCell.self, xib: true)
        tableView.registerCell(OptionCell.self, xib: true)

        scanButton.backgroundColor = .vividBlue
        scanButton.setTitle("ACTION SCAN".localized, for: .normal)
        scanButton.titleLabel?.font = .systemFont(ofSize: 17)
        if #available(iOS 10.0, *) {
            scanButton.titleLabel?.adjustsFontForContentSizeCategory = true
        }
        
        thumbsView = GalleryThumbsView.showInToolbar(of: self, tintColor: .vividBlue)
        
        navigationItem.rightBarButtonItem = PreferencesVC.settingsBarButtonItem(target: self, action: #selector(self.settingsButtonTap))
        
        tableView.sy_addPullToResfresh { [weak self] (_) in
            self?.refresh()
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.prefsChangedNotification), name: Preferences.preferencesChanged, object: nil)
        
        tableView.sy_showPullToRefresh(runBlock: true)
    }

    deinit {
        Sane.shared.closeDevice(device)
        NotificationCenter.default.removeObserver(self, name: Preferences.preferencesChanged, object: nil)
    }
    
    // MARK: Properties
    // TODO: use non nullable
    private let device: SYSaneDevice
    private var isRefreshing: Bool = false
    
    // MARK: Views
    private var thumbsView: GalleryThumbsView!
    @IBOutlet private var tableView: UITableView!
    @IBOutlet private var scanButton: UIButton!
    
    // MARK: Actions
    @IBAction private func scanButtonTap() {
    }
    
    
    // TODO: cleanup
    private func scanButtonTapBis() {
        SVProgressHUD.show(withStatus: "SCANNING".localized)
        Sane.shared.scan(device: device, progress: { (progress, incompleteImage) in
            SVProgressHUD.showProgress(progress)
        }) { (image, parameters, error) in
            if let error = error {
                SVProgressHUD.showError(withStatus: error.localizedDescription)
            }
            if let image = image, let parameters = parameters, let metadata = self.imageMetadata(scanParameters: parameters) {
                GalleryManager.shared.addImage(image, metadata: metadata)
                SVProgressHUD.showSuccess(status: nil, duration: 1)
            }
        }
    }
    
    @objc private func settingsButtonTap() {
        // TODO: add in static method PreferencesVC barbuttonitem
        let nc = UINavigationController(rootViewController: PreferencesVC())
        nc.modalPresentationStyle = .formSheet
        present(nc, animated: true, completion: nil)
    }
    
    private func shareItem(_ item: MHGalleryItem?) {
        guard let url = item?.url else { return }
        UIActivityViewController.showForURLs([url], fromBottomIn: self, completion: nil)
    }
    
    @objc private func prefsChangedNotification() {
        tableView.reloadData()
    }
    
    // MARK: Content
    private func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        
        Sane.shared.listOptions(for: device) { [weak self] in
            guard let self = self else { return }
            self.tableView.reloadData()
            self.isRefreshing = false
            self.tableView.sy_endPullToRefresh()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.prepareForSnapshotting()
            }
        }
    }
    
    func optionGroups() -> [SYSaneOptionGroup] {
        return device.filteredGroupedOptionsWithoutAdvanced(!Preferences.shared.showAdvancedOptions) ?? []
    }
    
    func optionGroup(tableViewSection section: Int) -> SYSaneOptionGroup? {
        guard section - 1 < optionGroups().count else { return nil }
        return optionGroups()[section - 1]
    }
    
    func option(tableViewIndexPath: IndexPath) -> SYSaneOption? {
        return optionGroup(tableViewSection: tableViewIndexPath.section)?.items[tableViewIndexPath.row]
    }

    private func updatePreviewCell(cropAreaPercent: CGRect) {
        guard device.canCrop else { return }
        
        var cropArea = CGRect()
        cropArea.origin.x = device.maxCropArea.origin.x + device.maxCropArea.width * cropAreaPercent.origin.x
        cropArea.origin.y = device.maxCropArea.origin.y + device.maxCropArea.height * cropAreaPercent.origin.y
        cropArea.size.width = device.maxCropArea.width * cropAreaPercent.width
        cropArea.size.height = device.maxCropArea.height * cropAreaPercent.height

        device.cropArea = device.maxCropArea.intersection(cropArea)
        
        if let previewCell = tableView.visibleCells.compactMap({ $0 as? PreviewCell }).first {
            previewCell.refresh()
        }
    }
    
    private func updatePreviewImageCell(image: UIImage?) {
        // update only if we scanned without cropping
        guard device.cropArea == device.maxCropArea else { return }
    
        // update only if we don't require color mode to be set at auto, or when auto is not available
        guard !Preferences.shared.previewWithAutoColorMode || device.standardOption(.colorMode)?.capSetAuto != true else { return }
    
        device.lastPreviewImage = image
        
        if let previewCell = tableView.visibleCells.compactMap({ $0 as? PreviewCell }).first {
            previewCell.refresh()
        }
    }
    

}

// MARK: Snapshots
extension DeviceVC {
    private func prepareForSnapshotting() {
        let snapshotType = AppDelegate.obtain.snapshotType
        guard snapshotType != .none else { return }
    
        if snapshotType == .devicePreview || snapshotType == .deviceOptions || snapshotType == .deviceOptionPopup {
            let rect = CGRect(x: 0.1, y: 0.2, width: 0.8, height: 0.6)
            // TODO: path? named?
            if let path = AppDelegate.obtain.snapshotTestScanImagePath {
                device.lastPreviewImage = UIImage(named: path)
            }
            updatePreviewCell(cropAreaPercent: rect)
        }

        if snapshotType == .deviceOptions || snapshotType == .deviceOptionPopup {
            let firstOption = IndexPath(row: 0, section: 1)
            tableView.scrollToRow(at: firstOption, at: .top, animated: false)
        }
    
        if snapshotType == .deviceOptionPopup {
            let firstOption = IndexPath(row: 0, section: 1)
            self.tableView(tableView, didSelectRowAt: firstOption)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            SVProgressHUD.dismiss()
        }
    }
}

extension DeviceVC {
    func imageMetadata(scanParameters: SYSaneScanParameters) -> SYMetadata? {

        let optionResX = device.standardOption(.resolutionX) as? SYSaneOptionNumber
        let optionResY = device.standardOption(.resolutionY) as? SYSaneOptionNumber
        let optionRes = device.standardOption(.resolution) as? SYSaneOptionNumber
        
        guard let resXInches = optionResX?.value ?? optionRes?.value, let resYInches = optionResY?.value ?? optionRes?.value else { return nil }

        let resXMeters = Int(round(resXInches.doubleValue / 2.54 * 100))
        let resYMeters = Int(round(resYInches.doubleValue / 2.54 * 100))
        
        let metadata = SYMetadata()!
        
        metadata.metadataTIFF = SYMetadataTIFF()
        metadata.metadataTIFF.orientation = SYPictureTiffOrientation_TopLeft.rawValue as NSNumber
        metadata.metadataTIFF.make = device.vendor
        metadata.metadataTIFF.model = device.model
        metadata.metadataTIFF.software = (Bundle.main.localizedName ?? "") + " " + Bundle.main.fullVersion
        metadata.metadataTIFF.xResolution = resXInches
        metadata.metadataTIFF.yResolution = resYInches
        metadata.metadataTIFF.resolutionUnit = 2 // 2 = inches, let's hope it'll make sense for every device
        
        metadata.metadataPNG = SYMetadataPNG()
        metadata.metadataPNG.xPixelsPerMeter = resXMeters as NSNumber
        metadata.metadataPNG.yPixelsPerMeter = resYMeters as NSNumber
        
        metadata.metadataJFIF = SYMetadataJFIF()
        metadata.metadataJFIF.xDensity = resXInches
        metadata.metadataJFIF.yDensity = resYInches
        
        return metadata
    }
}

extension DeviceVC : UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        if device.allOptions?.count == 0 {
            return 0
        }
        return optionGroups().count + 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 { return 1 }
        return optionGroup(tableViewSection: section)?.items.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueCell(PreviewCell.self, for: indexPath)
            cell.device = device
            return cell
        }
        
        let cell = tableView.dequeueCell(OptionCell.self, for: indexPath)
        if let option = option(tableViewIndexPath: indexPath) {
            cell.updateWith(option: option)
        }
        cell.showDescription = false
        return cell
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 { return "DEVICE SECTION PREVIEW".localized }
        return optionGroup(tableViewSection: section)?.localizedTitle
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let width = tableView.bounds.width
        var maxHeight = tableView.bounds.height * 2 / 3
        
        if traitCollection.verticalSizeClass == .compact {
            maxHeight = 500
        }
        
        if indexPath.section == 0 {
            return PreviewCell.cellHeight(device: device, width: width, maxHeight: maxHeight)
        }
        
        if let option = option(tableViewIndexPath: indexPath) {
            return OptionCell.cellHeight(option: option, showDescription: false, width: width)
        }
        
        return 0
    }
}

extension DeviceVC : UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        guard indexPath.section > 0, let option = option(tableViewIndexPath: indexPath) else { return }
        
        let completion = { (error: Error?) -> Void in
            self.tableView.reloadData()
            if let error = error {
                SVProgressHUD.showError(withStatus: error.localizedDescription)
            }
            else {
                SVProgressHUD.dismiss()
            }
        }
        
        SaneOptionUI.showDetailsAndInput(for: option) { (reloadAll, error) in
            if reloadAll {
                Sane.shared.listOptions(for: self.device, completion: {
                    completion(error)
                })
            }
            else {
                completion(error)
            }
        }
    }
}

// TODO: cleanup

/*

#pragma mark - Notifications

#pragma mark - IBActions

    - (void)buttonScanTap:(id)sender
{
    __block DLAVAlertView *alertView;
    __block UIImageView *alertViewImageView;
    __block MHGalleryItem *item;
    
    @weakify(self);
    void(^block)(float progress, BOOL finished, UIImage *image, SYSaneScanParameters *parameters, NSError *error) =
    ^(float progress, BOOL finished, UIImage *image, SYSaneScanParameters *parameters, NSError *error)
    {
        @strongify(self)
        // Finished with error
        if (error)
        {
            [alertView dismissWithClickedButtonIndex:alertView.cancelButtonIndex animated:NO];
            [SVProgressHUD showErrorWithStatus:error.sy_alertMessage];
            return;
        }
        
        // Finished without error
        if (finished)
        {
            SYMetadata *metadata = [self metadataForSaneParameters:parameters];
            item = [[SYGalleryManager shared] addImage:image metadata:metadata];
            [SVProgressHUD dismiss];
            [self updatePreviewImageCellWithImage:image];
        }
        
        // need to show image (finished or partial with preview)
        if (!alertView && image)
        {
            alertView = [[DLAVAlertView alloc] initWithTitle:$("DIALOG TITLE SCANNED IMAGE")
                message:nil
                delegate:nil
                cancelButtonTitle:$("ACTION CLOSE")
                otherButtonTitles:$("ACTION SHARE"), nil];
            
            alertViewImageView = [alertView addImageViewForImage:image];
            [alertView showWithCompletion:^(DLAVAlertView *alertView, NSInteger buttonIndex)
                {
                if (buttonIndex == alertView.cancelButtonIndex)
                return;
                
                [self shareItem:item];
                }];
            [SVProgressHUD dismiss];
        }
        
        // update alertview
        [alertView setButtonsEnabled:finished];
        
        // update image for partial preview
        if (image)
        {
            [alertViewImageView setImage:image];
        }
        
        // update progress when no partial preview
        if (!finished && !image)
        {
            [SVProgressHUD showProgress:progress];
        }
    };
    
    [SVProgressHUD showWithStatus:$("SCANNING")];
    [Sane.shared scanWithDevice:self.device progress:^(float progress, UIImage * _Nullable incompleteImage) {
        block(progress, NO, incompleteImage, nil, nil);
        } completion:^(UIImage *image,SYSaneScanParameters *parameters, NSError *error) {
        block(1., YES, image, parameters, error);
        }];
    }
    
@end
*/
