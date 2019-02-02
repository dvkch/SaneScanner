//
//  SYDevicesVC.m
//  SaneScanner
//
//  Created by rominet on 06/05/15.
//  Copyright (c) 2015 Syan. All rights reserved.
//

#import "SYDevicesVC.h"
#import "SYTools.h"
#import <SaneSwift/SaneSwift-umbrella.h>
#import "SYSaneDevice.h"
#import <DLAVAlertView.h>
#import "SYDeviceVC.h"
#import "SVProgressHUD.h"
#import "SYPrefVC.h"
#import "SYGalleryThumbsView.h"
#import <Masonry.h>
#import "SYAppDelegate.h"
#import "SYGalleryManager.h"
#import "SYGalleryController.h"
#import "UIScrollView+SY.h"
#import "UIApplication+SY.h"
#import "UIViewController+SYKit.h"
#import "SaneScanner-Swift.h"

@interface SYDevicesVC () <UITableViewDataSource, UITableViewDelegate, SaneDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) SYGalleryThumbsView *thumbsView;
@property (nonatomic, strong) NSArray <SYSaneDevice *> *devices;
@end

@implementation SYDevicesVC

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self.view setBackgroundColor:[UIColor groupTableViewBackgroundColor]];
    
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    [self.tableView setDataSource:self];
    [self.tableView setDelegate:self];
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:[UITableViewCell sy_className]];
    [self.tableView registerNib:[UINib nibWithNibName:$$("DeviceCell") bundle:nil] forCellReuseIdentifier:DeviceCell.sy_className];
    [self.tableView registerNib:[UINib nibWithNibName:$$("AddCell") bundle:nil] forCellReuseIdentifier:AddCell.sy_className];
    [self.view addSubview:self.tableView];
    
    self.thumbsView = [SYGalleryThumbsView showInToolbarOfController:self tintColor:nil];
    
    [self.navigationItem setRightBarButtonItem:
     [SYPrefVC barButtonItemWithTarget:self action:@selector(buttonSettingsTap:)]];
    
    [self.tableView sy_addPullToResfreshWithBlock:^(UIScrollView * _) {
        [self refreshDevices];
    }];
    
    Sane.shared.delegate = self;
    
    [self.tableView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.view);
    }];
    
    [self sy_setBackButtonWithText:nil font:nil];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self setTitle:[[UIApplication sharedApplication] sy_localizedName]];
    [self.tableView reloadData];
    
    // TODO: remove ability to call block, should run Sane refresh instead that itself triggers this
    if (!self.devices)
        [self refreshDevices];
}

#pragma mark - IBActions

- (void)refreshDevices {
    [Sane.shared updateDevicesWithCompletion:^(NSArray<SYSaneDevice *> * _Nullable devices, NSError * _Nullable error) {
        self.devices = devices;
        [self.tableView reloadData];
        
        // in case it was opened (e.g. for screenshots)
        [SVProgressHUD dismiss];
        
        if (error)
            [SVProgressHUD showErrorWithStatus:error.sy_alertMessage];
    }];
}

- (void)buttonSettingsTap:(id)sender
{
    SYPrefVC *prefVC = [[SYPrefVC alloc] init];
    UINavigationController *nc = [[UINavigationController alloc] initWithRootViewController:prefVC];
    [nc setModalPresentationStyle:UIModalPresentationFormSheet];
    [self presentViewController:nc animated:YES completion:nil];
}

#pragma mark - SYSaneHelperDelegate

- (void)saneDidStartUpdatingDevices:(Sane *)sane
{
    [self.tableView sy_showPullToRefreshAndRunBlock:NO];
}

- (void)saneDidEndUpdatingDevices:(Sane *)sane
{
    [self.tableView reloadData];
    [self.tableView sy_endPullToRefresh];
}

- (DeviceAuthentication *)saneNeedsAuth:(Sane *)sane for:(NSString *)device
{
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    __block NSString *outUsername;
    __block NSString *outPassword;
    
    dispatch_async(dispatch_get_main_queue(), ^
    {
        DLAVAlertView *alertView =
        [[DLAVAlertView alloc] initWithTitle:$("DIALOG TITLE AUTH")
                                     message:[NSString stringWithFormat:$("DIALOG MESSAGE AUTH %@"), device]
                                    delegate:nil
                           cancelButtonTitle:$("ACTION CANCEL")
                           otherButtonTitles:$("ACTION CONTINUE"), nil];
        
        [alertView setAlertViewStyle:DLAVAlertViewStyleLoginAndPasswordInput];
        [[alertView textFieldAtIndex:0] setBorderStyle:UITextBorderStyleNone];
        [[alertView textFieldAtIndex:1] setBorderStyle:UITextBorderStyleNone];
        [alertView showWithCompletion:^(DLAVAlertView *alertView, NSInteger buttonIndex) {
            if (buttonIndex != alertView.cancelButtonIndex)
            {
                outUsername = [alertView textFieldAtIndex:0].text;
                outPassword = [alertView textFieldAtIndex:1].text;
            }
            dispatch_semaphore_signal(semaphore);
        }];
    });
    
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    
    return [[DeviceAuthentication alloc] initWithUsername:outUsername password:outPassword];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return section == 0 ? (Sane.shared.configuration.hosts.count + 1) : self.devices.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0)
    {
        if (indexPath.row < Sane.shared.configuration.hosts.count)
        {
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:[UITableViewCell sy_className]];
            [cell.textLabel setText:Sane.shared.configuration.hosts[indexPath.row]];
            [cell setAccessoryType:UITableViewCellAccessoryNone];
            return cell;
        }
        else
        {
            AddCell *cell = (AddCell *)[tableView dequeueReusableCellWithIdentifier:AddCell.sy_className];
            [cell setTitle:$("DEVICES ROW ADD HOST")];
            return cell;
        }
    }
    else
    {
        DeviceCell *cell = [tableView dequeueReusableCellWithIdentifier:[DeviceCell sy_className]];
        [cell setDevice:self.devices[indexPath.row]];
        return cell;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return section == 0 ? $("DEVICES SECTION HOSTS") : $("DEVICES SECTION DEVICES");
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section != 0)
        return;
    
    if (indexPath.row >= Sane.shared.configuration.hosts.count)
        return;
    
    [Sane.shared.configuration removeHost:Sane.shared.configuration.hosts[indexPath.row]];
    
    [self.tableView beginUpdates];
    [self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationBottom];
    [self.tableView endUpdates];
    
    [self.tableView sy_showPullToRefreshAndRunBlock:YES];
}

#pragma mark - UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return indexPath.section == 0 ? 44 : 52;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0)
    {
        if (indexPath.row < Sane.shared.configuration.hosts.count)
            return UITableViewCellEditingStyleDelete;
        else
            return UITableViewCellEditingStyleNone;
    }
    else
        return UITableViewCellEditingStyleNone;
}

- (NSString *)tableView:(UITableView *)tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return $("ACTION REMOVE");
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (indexPath.section == 0 && indexPath.row >= Sane.shared.configuration.hosts.count)
    {
        DLAVAlertView *av = [[DLAVAlertView alloc] initWithTitle:$("DIALOG TITLE ADD HOST")
                                                         message:$("DIALOG MESSAGE ADD HOST")
                                                        delegate:nil
                                               cancelButtonTitle:$("ACTION CANCEL")
                                               otherButtonTitles:$("ACTION ADD"), nil];
        
        [av setAlertViewStyle:DLAVAlertViewStylePlainTextInput];
        [[av textFieldAtIndex:0] setBorderStyle:UITextBorderStyleNone];
        [av showWithCompletion:^(DLAVAlertView *alertView, NSInteger buttonIndex)
        {
            if (buttonIndex == alertView.cancelButtonIndex)
                return;
            
            NSString *host = [[av textFieldAtIndex:0] text];
            [Sane.shared.configuration addHost:host];
            [self.tableView reloadData];
            [self.tableView sy_showPullToRefreshAndRunBlock:YES];
        }];
        
        return;
    }
    
    else if (indexPath.section == 0)
        return;
    
    SYSaneDevice *device = self.devices[indexPath.row];
    
    [SVProgressHUD showWithStatus:$("LOADING")];
    [Sane.shared openDevice:device completion:^(NSError * _Nullable error) {
        if ([SYAppDelegate obtain].snapshotType == SYSnapshotType_None)
            [SVProgressHUD dismiss];
        
        if (error)
        {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:$("DIALOG TITLE COULDNT OPEN DEVICE")
                                                                           message:error.sy_alertMessage
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:$("ACTION CLOSE") style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
        }
        else
        {
            SYDeviceVC *vc = [[SYDeviceVC alloc] init];
            [vc setDevice:device];
            [self.navigationController pushViewController:vc animated:YES];
        }
    }];
}

@end
