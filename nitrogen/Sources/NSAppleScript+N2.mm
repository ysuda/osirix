//
//  NSAppleScript+N2.mm
//  OsiriX_Lion
//
//  Created by Alessandro Volz on 03.10.11.
//  Copyright 2011 OsiriX Team. All rights reserved.
//

#import "NSAppleScript+N2.h"
#import "NSAppleEventDescriptor+N2.h"
#import "N2Debug.h"


@implementation NSAppleScript (N2)

-(id)runWithArguments:(NSArray*)args error:(NSDictionary**)errs {
    if (!args)
        args = [NSArray array];
    
    NSAppleEventDescriptor* event = [NSAppleEventDescriptor appleEventWithEventClass:kCoreEventClass eventID:kAEOpenApplication targetDescriptor:nil returnID:kAutoGenerateReturnID transactionID:kAnyTransactionID];
    [event setDescriptor:[args appleEventDescriptor] forKeyword:keyDirectObject];
    
    NSAppleEventDescriptor* r = nil;
    
    @try {
        r = [self executeAppleEvent:event error:errs];
    }
    @catch (NSException *e) {
        N2LogExceptionWithStackTrace( e);
    }
    
    return [r object];
}

@end
