//
//  SYSaneOptionUI.m
//  SaneScanner
//
//  Created by Stan Chevallier on 06/03/2016.
//  Copyright © 2016 Syan. All rights reserved.
//

#import "SYSaneOptionUI.h"
#import "SYSaneOptionBool.h"
#import "SYSaneOptionInt.h"
#import "SYSaneOptionDouble.h"
#import "SYSaneOptionString.h"
#import "SYSaneOptionButton.h"
#import "SYSaneOptionGroup.h"
#import <SVProgressHUD.h>
#import <PKYStepper.h>
#import "SYSaneHelper.h"
#import "DLAVAlertView+SY.h"

@implementation SYSaneOptionUI

+ (void)showDetailsForOption:(SYSaneOption *)option;
{
    [[[DLAVAlertView alloc] initWithTitle:option.title
                                 message:option.desc
                                delegate:nil
                       cancelButtonTitle:@"Close"
                       otherButtonTitles:nil] show];
}

+ (void)showDetailsAndInputForOption:(SYSaneOption *)option block:(void (^)(BOOL, NSString *))block
{
    if (option.readOnlyOrSingleOption)
    {
        [self showDetailsForOption:option];
        return;
    }
    
    switch (option.type) {
        case SANE_TYPE_BOOL:
            [self showInputForOptionsTitles:@[@"On", @"Off"] optionValues:@[@(YES), @(NO)] forOption:option block:block];
            break;
        case SANE_TYPE_INT:
        case SANE_TYPE_FIXED:
        {
            NSArray <NSNumber *> *discreetValues;
            if (option.type == SANE_TYPE_INT)
                discreetValues = [(SYSaneOptionInt *)option constraintValues];
            else
                discreetValues = [(SYSaneOptionDouble *)option constraintValues];
            
            NSArray <NSString *> *titles;
            if (option.type == SANE_TYPE_INT)
                titles = [(SYSaneOptionInt *)option constraintValuesWithUnit:YES];
            else
                titles = [(SYSaneOptionDouble *)option constraintValuesWithUnit:YES];
            
            if (option.constraintType == SANE_CONSTRAINT_RANGE)
                [self showInputWithSliderForOption:option block:block];
            else
            {
                [self showInputForOptionsTitles:titles
                                   optionValues:discreetValues
                                      forOption:option
                                          block:block];
            }
            break;
        }
        case SANE_TYPE_STRING:
        {
            SYSaneOptionString *castedOption = (SYSaneOptionString *)option;
            if (castedOption.constraintType == SANE_CONSTRAINT_NONE)
                [self showInputWithTextFieldForOption:option
                                                block:block];
            else
                [self showInputForOptionsTitles:castedOption.constraintValues
                                   optionValues:castedOption.constraintValues
                                      forOption:option
                                          block:block];
            break;
        }
        case SANE_TYPE_BUTTON:
            [self showInputForButtonOption:(SYSaneOptionButton *)option block:block];
            break;
        case SANE_TYPE_GROUP:
            [self showDetailsForOption:option];
            break;
    }
}

+ (void)showInputForButtonOption:(SYSaneOption *)option
                           block:(void(^)(BOOL reloadAllOptions, NSString *error))block
{
    [[[DLAVAlertView alloc] initWithTitle:option.title
                                  message:option.desc
                                 delegate:nil
                        cancelButtonTitle:@"Close"
                        otherButtonTitles:@"Press", nil]
     showWithCompletion:^(DLAVAlertView *alertView, NSInteger buttonIndex) {
         if (buttonIndex == alertView.cancelButtonIndex)
             return;
         
         [[SYSaneHelper shared] setValue:@YES
                             orAutoValue:NO
                               forOption:option
                         thenReloadValue:YES
                                   block:block];
     }];
}

+ (void)showInputWithTextFieldForOption:(SYSaneOption *)option
                                  block:(void(^)(BOOL reloadAllOptions, NSString *error))block
{
    DLAVAlertView *alertView = [[DLAVAlertView alloc] initWithTitle:option.title
                                                            message:option.desc
                                                           delegate:nil
                                                  cancelButtonTitle:nil
                                                  otherButtonTitles:nil];
    
    if (option.capSetAuto)
        [alertView addButtonWithTitle:@"Auto"];
    
    [alertView addButtonWithTitle:@"Update value"];
    [alertView addButtonWithTitle:@"Close"];
    
    [alertView setAlertViewStyle:DLAVAlertViewStylePlainTextInput];
    
    switch (option.type) {
        case SANE_TYPE_INT:
            [[alertView textFieldAtIndex:0] setKeyboardType:UIKeyboardTypeNumberPad];
            break;
        case SANE_TYPE_FIXED:
            [[alertView textFieldAtIndex:0] setKeyboardType:UIKeyboardTypeNumbersAndPunctuation];
            break;
        case SANE_TYPE_STRING:
            [[alertView textFieldAtIndex:0] setKeyboardType:UIKeyboardTypeDefault];
            break;
        case SANE_TYPE_BOOL:
        case SANE_TYPE_BUTTON:
        case SANE_TYPE_GROUP:
            break;
    }
    
    [alertView showWithCompletion:^(DLAVAlertView *alertView, NSInteger buttonIndex) {
        if (alertView.lastOtherButtonIndex == buttonIndex)
            return;
        
        BOOL useAuto = (buttonIndex == alertView.firstOtherButtonIndex && option.capSetAuto);
        [SVProgressHUD show];
        [[SYSaneHelper shared] setValue:[alertView textFieldAtIndex:0].text
                            orAutoValue:useAuto
                              forOption:option
                        thenReloadValue:YES
                                  block:block];
    }];
}

+ (void)showInputWithSliderForOption:(SYSaneOption *)option
                               block:(void(^)(BOOL reloadAllOptions, NSString *error))block
{
    DLAVAlertView *alertView = [[DLAVAlertView alloc] initWithTitle:option.title
                                                            message:option.desc
                                                           delegate:nil
                                                  cancelButtonTitle:nil
                                                  otherButtonTitles:nil];
    
    if (option.capSetAuto)
        [alertView addButtonWithTitle:@"Auto"];
    [alertView addButtonWithTitle:@"Update value"];
    [alertView addButtonWithTitle:@"Close"];
    
    NSUInteger updateButtonIndex = alertView.firstOtherButtonIndex + (option.capSetAuto ? 1 : 0);
    
    if (option.type == SANE_TYPE_INT)
    {
        SYSaneOptionInt *castedOption = (SYSaneOptionInt *)option;
        if (castedOption.stepValue == 0)
        {
            [alertView addSliderWithMin:castedOption.minValue
                                    max:castedOption.maxValue
                                current:castedOption.value
                            updateBlock:^(DLAVAlertView *alertView, float value)
             {
                 NSString *valueString = [option stringForValue:@(value) withUnit:YES];
                 NSString *buttonTitle = [NSString stringWithFormat:@"Set to %@", valueString];
                 [alertView setText:buttonTitle forButtonAtIndex:updateButtonIndex];
             }];
        }
        else
        {
            PKYStepper *stepper = [[PKYStepper alloc] initWithFrame:CGRectMake(0, 0, 300, 40)];
            [stepper setMaximum:castedOption.maxValue];
            [stepper setMinimum:castedOption.minValue];
            [stepper setValue:castedOption.value];
            [stepper setValueChangedCallback:^(PKYStepper *stepper, float count) {
                stepper.countLabel.text = [option stringForValue:@(count) withUnit:YES];
            }];
            [stepper setup];
            [alertView setContentView:stepper];
        }
    }
    if (option.type == SANE_TYPE_FIXED)
    {
        SYSaneOptionDouble *castedOption = (SYSaneOptionDouble *)option;
        if (castedOption.stepValue == 0)
        {
            [alertView addSliderWithMin:castedOption.minValue
                                    max:castedOption.maxValue
                                current:castedOption.value
                            updateBlock:^(DLAVAlertView *alertView, float value)
            {
                NSString *valueString = [option stringForValue:@(value) withUnit:YES];
                NSString *buttonTitle = [NSString stringWithFormat:@"Set to %@", valueString];
                [alertView setText:buttonTitle forButtonAtIndex:updateButtonIndex];
            }];
        }
        else
        {
            PKYStepper *stepper = [[PKYStepper alloc] initWithFrame:CGRectMake(0, 0, 300, 40)];
            [stepper setMaximum:castedOption.maxValue];
            [stepper setMinimum:castedOption.minValue];
            [stepper setValue:castedOption.value];
            [stepper setValueChangedCallback:^(PKYStepper *stepper, float count) {
                stepper.countLabel.text = [option stringForValue:@(count) withUnit:YES];
            }];
            [stepper setup];
            [alertView setContentView:stepper];
        }
    }
    
    [alertView showWithCompletion:^(DLAVAlertView *alertView, NSInteger buttonIndex) {
        if (alertView.lastOtherButtonIndex == buttonIndex)
            return;
        
        BOOL useAuto = (buttonIndex == alertView.firstOtherButtonIndex && option.capSetAuto);
        [SVProgressHUD show];
        
        double value = 0.;
        if ([alertView.contentView isKindOfClass:[UISlider class]])
            value = [(UISlider *)alertView.contentView value];
        if ([alertView.contentView isKindOfClass:[PKYStepper class]])
            value = [(PKYStepper *)alertView.contentView value];
        
        [[SYSaneHelper shared] setValue:@(value)
                            orAutoValue:useAuto
                              forOption:option
                        thenReloadValue:YES
                                  block:block];
    }];

}

+ (void)showInputForOptionsTitles:(NSArray <NSString *> *)titles
                     optionValues:(NSArray *)values
                        forOption:(SYSaneOption *)option
                            block:(void(^)(BOOL reloadAllOptions, NSString *error))block
{
    NSMutableArray <NSString *> *optionsTitles = [NSMutableArray array];
    NSMutableArray              *optionsValues = [NSMutableArray array];
    
    if (option.capSetAuto)
    {
        [optionsTitles addObject:@"Auto"];
        [optionsValues addObject:[NSNull null]];
    }
    
    [optionsValues addObjectsFromArray:values];
    [optionsTitles addObjectsFromArray:titles];
    
    DLAVAlertView *alertView = [[DLAVAlertView alloc] initWithTitle:option.title
                                                            message:option.desc
                                                           delegate:nil
                                                  cancelButtonTitle:nil
                                                  otherButtonTitles:nil];
    
    for (NSString *title in optionsTitles)
        [alertView addButtonWithTitle:title];
    
    [alertView addButtonWithTitle:@"Close"];
    
    [alertView showWithCompletion:^(DLAVAlertView *alertView, NSInteger buttonIndex) {
        if (alertView.lastOtherButtonIndex == buttonIndex)
            return;
        
        id value = optionsValues[buttonIndex - alertView.firstOtherButtonIndex];
        BOOL useAuto = [value isEqual:[NSNull null]];
        
        [SVProgressHUD show];
        [[SYSaneHelper shared] setValue:value
                            orAutoValue:useAuto
                              forOption:option
                        thenReloadValue:YES
                                  block:block];
    }];
}

@end
