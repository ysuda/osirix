/*=========================================================================
 Program:   OsiriX
 
 Copyright (c) OsiriX Team
 All rights reserved.
 Distributed under GNU - LGPL
 
 See http://www.osirix-viewer.com/copyright.html for details.
 
 This software is distributed WITHOUT ANY WARRANTY; without even
 the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
 PURPOSE.
 =========================================================================*/

#import "OSIROIMask.h"
#import "OSIFloatVolumeData.h"
#import "OSIROIMaskRunStack.h"

const OSIROIMaskRun OSIROIMaskRunZero = {{0.0, 0.0}, 0, 0, 1.0};

@interface OSIMaskIndexPredicateStandIn : NSObject
{
    float intensity;
    float ROIMaskIntensity;
    NSUInteger ROIMaskIndexX;
    NSUInteger ROIMaskIndexY;
    NSUInteger ROIMaskIndexZ;
}
@property (nonatomic, readwrite, assign) float intensity;
@property (nonatomic, readwrite, assign) float ROIMaskIntensity;
@property (nonatomic, readwrite, assign) NSUInteger ROIMaskIndexX;
@property (nonatomic, readwrite, assign) NSUInteger ROIMaskIndexY;
@property (nonatomic, readwrite, assign) NSUInteger ROIMaskIndexZ;
@end
@implementation OSIMaskIndexPredicateStandIn
@synthesize intensity;
@synthesize ROIMaskIntensity;
@synthesize ROIMaskIndexX;
@synthesize ROIMaskIndexY;
@synthesize ROIMaskIndexZ;
@end


NSComparisonResult OSIROIMaskCompareRunValues(NSValue *maskRun1Value, NSValue *maskRun2Value, void *context)
{
    OSIROIMaskRun maskRun1 = [maskRun1Value OSIROIMaskRunValue];
    OSIROIMaskRun maskRun2 = [maskRun2Value OSIROIMaskRunValue];
    
    return OSIROIMaskCompareRun(maskRun1, maskRun2);
}


NSComparisonResult OSIROIMaskCompareRun(OSIROIMaskRun maskRun1, OSIROIMaskRun maskRun2)
{
    if (maskRun1.depthIndex < maskRun2.depthIndex) {
        return NSOrderedAscending;
    } else if (maskRun1.depthIndex > maskRun2.depthIndex) {
        return NSOrderedDescending;
    }
    
    if (maskRun1.heightIndex < maskRun2.heightIndex) {
        return NSOrderedAscending;
    } else if (maskRun1.heightIndex > maskRun2.heightIndex) {
        return NSOrderedDescending;
    }
    
    if (maskRun1.widthRange.location < maskRun2.widthRange.location) {
        return NSOrderedAscending;
    } else if (maskRun1.widthRange.location > maskRun2.widthRange.location) {
        return NSOrderedDescending;
    }
    
    return NSOrderedSame;
}

BOOL OSIROIMaskRunsOverlap(OSIROIMaskRun maskRun1, OSIROIMaskRun maskRun2)
{
    if (maskRun1.depthIndex == maskRun2.depthIndex && maskRun1.heightIndex == maskRun2.heightIndex) {
        return NSIntersectionRange(maskRun1.widthRange, maskRun2.widthRange).length != 0;
    }
    
    return NO;
}

BOOL OSIROIMaskRunsAbut(OSIROIMaskRun maskRun1, OSIROIMaskRun maskRun2)
{
    if (maskRun1.depthIndex == maskRun2.depthIndex && maskRun1.heightIndex == maskRun2.heightIndex) {
        if (NSMaxRange(maskRun1.widthRange) == maskRun2.widthRange.location ||
            NSMaxRange(maskRun2.widthRange) == maskRun1.widthRange.location) {
            return YES;
        }
    }
    return NO;
}

BOOL OSIROIMaskIndexInRun(OSIROIMaskIndex maskIndex, OSIROIMaskRun maskRun)
{
	if (maskIndex.y != maskRun.heightIndex || maskIndex.z != maskRun.depthIndex) {
		return NO;
	}
	if (NSLocationInRange(maskIndex.x, maskRun.widthRange)) {
		return YES;
	} else {
		return NO;
	}
}

NSArray *OSIROIMaskIndexesInRun(OSIROIMaskRun maskRun)
{
	NSMutableArray *indexes;
	NSUInteger i;
	OSIROIMaskIndex index;
	
	indexes = [NSMutableArray array];
	index.y = maskRun.heightIndex;
	index.z = maskRun.depthIndex;
	
	for (i = maskRun.widthRange.location; i < NSMaxRange(maskRun.widthRange); i++) {
		index.x = i;
		[indexes addObject:[NSValue valueWithOSIROIMaskIndex:index]];
	}
	return indexes;
}

@interface OSIROIMask ()
- (void)checkdebug;
@end

@implementation OSIROIMask

+ (id)ROIMask
{
    return [[[[self class] alloc] init] autorelease];
}


+ (id)ROIMaskFromVolumeData:(OSIFloatVolumeData *)floatVolumeData
{
    NSInteger i;
    NSInteger j;
    NSInteger k;
    float intensity;
    NSMutableArray *maskRuns;
    OSIROIMaskRun maskRun;
    CPRVolumeDataInlineBuffer inlineBuffer;
        
    maskRuns = [NSMutableArray array];
    maskRun = OSIROIMaskRunZero;
    maskRun.intensity = 0.0;
    
    if ([floatVolumeData aquireInlineBuffer:&inlineBuffer]) {
        for (k = 0; k < inlineBuffer.pixelsDeep; k++) {
            for (j = 0; j < inlineBuffer.pixelsHigh; j++) {
                for (i = 0; i < inlineBuffer.pixelsWide; i++) {
                    intensity = CPRVolumeDataGetFloatAtPixelCoordinate(&inlineBuffer, i, j, k);
                    intensity = roundf(intensity*255.0f)/255.0f;
                    
                    if (intensity != maskRun.intensity) { // maybe start a run, maybe close a run
                        if (maskRun.intensity != 0) { // we need to end the previous run
                            [maskRuns addObject:[NSValue valueWithOSIROIMaskRun:maskRun]];
                            maskRun = OSIROIMaskRunZero;
                            maskRun.intensity = 0.0;
                        }
                        
                        if (intensity != 0) { // we need to start a new mask run
                            maskRun.depthIndex = k;
                            maskRun.heightIndex = j;
                            maskRun.widthRange = NSMakeRange(i, 1);
                            maskRun.intensity = intensity;
                        }
                    } else  { // maybe extend a run // maybe do nothing
                        if (intensity != 0) { // we need to extend the run
                            maskRun.widthRange.length += 1;
                        }
                    }
                }
                // after each run scan line we need to close out any open mask run
                if (maskRun.intensity != 0) {
                    [maskRuns addObject:[NSValue valueWithOSIROIMaskRun:maskRun]];
                    maskRun = OSIROIMaskRunZero;
                    maskRun.intensity = 0.0;
                }
            }
        }
    }
    
    [floatVolumeData releaseInlineBuffer:&inlineBuffer];
    
    return [[[[self class] alloc] initWithMaskRuns:maskRuns] autorelease];    
}

- (id)init
{
	if ( (self = [super init]) ) {
		_maskRuns = [[NSArray alloc] init];
	}
	return self;
}

- (id)initWithMaskRuns:(NSArray *)maskRuns
{
	if ( (self = [super init]) ) {
		_maskRuns = [[maskRuns sortedArrayUsingFunction:OSIROIMaskCompareRunValues context:NULL] retain];
        [self checkdebug];
	}
	return self;
}

- (id)initWithSortedMaskRuns:(NSArray *)maskRuns
{
	if ( (self = [super init]) ) {
		_maskRuns = [maskRuns retain];
        [self checkdebug];
	}
	return self;
}

- (void)dealloc
{
    [_maskRunsData release];
    _maskRunsData = nil;
    [_maskRuns release];
    _maskRuns = nil;
    
    [super dealloc];
}

- (OSIROIMask *)ROIMaskByTranslatingByX:(NSInteger)x Y:(NSInteger)y Z:(NSInteger)z
{
    OSIROIMaskRun maskRun;
    NSValue *maskRunValue;
    NSMutableArray *newMaskRuns;
    
    newMaskRuns = [NSMutableArray arrayWithCapacity:[_maskRuns count]];
    
    for (maskRunValue in _maskRuns) {
        maskRun = [maskRunValue OSIROIMaskRunValue];
        
        assert((NSInteger)maskRun.widthRange.location >= -x);
        maskRun.widthRange.location += x;
        
        assert((NSInteger)maskRun.heightIndex >= -y);
        maskRun.heightIndex += y;
        
        assert((NSInteger)maskRun.depthIndex >= -z);
        maskRun.depthIndex += z;
        
        [newMaskRuns addObject:[NSValue valueWithOSIROIMaskRun:maskRun]];
    }
    
    return [[[[self class] alloc] initWithSortedMaskRuns:newMaskRuns] autorelease];
}

- (OSIROIMask *)ROIMaskByIntersectingWithMask:(OSIROIMask *)otherMask
{
    return [self ROIMaskBySubtractingMask:[self ROIMaskBySubtractingMask:otherMask]];
}

- (OSIROIMask *)ROIMaskByUnioningWithMask:(OSIROIMask *)otherMask
{
    NSUInteger index1 = 0;
    NSUInteger index2 = 0;
    
    OSIROIMaskRun run1;
    OSIROIMaskRun run2;
    
    OSIROIMaskRun runToAdd = OSIROIMaskRunZero;
    OSIROIMaskRun accumulatedRun = OSIROIMaskRunZero;
    accumulatedRun.widthRange.length = 0;
    
    NSData *maskRun1Data = [self maskRunsData];
    NSData *maskRun2Data = [otherMask maskRunsData];
    const OSIROIMaskRun *maskRunArray1 = [maskRun1Data bytes];
    const OSIROIMaskRun *maskRunArray2 = [maskRun2Data bytes];
    
    NSMutableArray *resultMaskRuns = [NSMutableArray array];
    
    
    while (index1 < [self maskRunCount] || index2 < [otherMask maskRunCount]) {
        if (index1 < [self maskRunCount] && index2 < [otherMask maskRunCount]) {
            if (OSIROIMaskCompareRun(maskRunArray1[index1], maskRunArray2[index2]) == NSOrderedAscending) {
                runToAdd = maskRunArray1[index1];
                index1++;
            } else {
                runToAdd = maskRunArray2[index2];
                index2++;
            }
        } else if (index1 < [self maskRunCount]) {
            runToAdd = maskRunArray1[index1];
            index1++;
        } else {
            runToAdd = maskRunArray2[index2];
            index2++;
        }
        
        if (accumulatedRun.widthRange.length == 0) {
            accumulatedRun = runToAdd;
        } else if (OSIROIMaskRunsOverlap(runToAdd, accumulatedRun) || OSIROIMaskRunsAbut(runToAdd, accumulatedRun)) {
            if (NSMaxRange(runToAdd.widthRange) > NSMaxRange(accumulatedRun.widthRange)) {
                accumulatedRun.widthRange.length = NSMaxRange(runToAdd.widthRange) - accumulatedRun.widthRange.location;
            }
        } else {
            [resultMaskRuns addObject:[NSValue valueWithOSIROIMaskRun:accumulatedRun]];
            accumulatedRun = runToAdd;
        }
    }
    
    if (accumulatedRun.widthRange.length != 0) {
        [resultMaskRuns addObject:[NSValue valueWithOSIROIMaskRun:accumulatedRun]];
    }
    
    return [[[OSIROIMask alloc] initWithSortedMaskRuns:resultMaskRuns] autorelease];
}


- (OSIROIMask *)ROIMaskBySubtractingMask:(OSIROIMask *)subtractMask
{
    OSIROIMaskRunStack *templateRunStack = [[OSIROIMaskRunStack alloc] initWithMaskRunData:[self maskRunsData]];
    OSIROIMaskRun newMaskRun;
    NSUInteger length;

    NSUInteger subtractIndex = 0;
    NSData *subtractData = [subtractMask maskRunsData];
    NSInteger subtractDataCount = [subtractData length]/sizeof(OSIROIMaskRun);
    const OSIROIMaskRun *subtractRunArray = [subtractData bytes];
   
    NSMutableArray *resultMaskRuns = [NSMutableArray array];

    while (subtractIndex < subtractDataCount && [templateRunStack count]) {
        if (OSIROIMaskRunsOverlap([templateRunStack currentMaskRun], subtractRunArray[subtractIndex]) == NO) {
            if (OSIROIMaskCompareRun([templateRunStack currentMaskRun], subtractRunArray[subtractIndex]) == NSOrderedAscending) {
                [resultMaskRuns addObject:[NSValue valueWithOSIROIMaskRun:[templateRunStack currentMaskRun]]];
                [templateRunStack popMaskRun];
            } else {
                subtractIndex++;
            }
        } else {
            // run the 4 cases
            if (NSLocationInRange([templateRunStack currentMaskRun].widthRange.location, subtractRunArray[subtractIndex].widthRange)) {
                if (NSLocationInRange(NSMaxRange([templateRunStack currentMaskRun].widthRange) - 1, subtractRunArray[subtractIndex].widthRange)) {
                    // 1.
                    [templateRunStack popMaskRun];
                } else {
                    // 2.
                    newMaskRun = [templateRunStack currentMaskRun];
                    length = NSIntersectionRange([templateRunStack currentMaskRun].widthRange, subtractRunArray[subtractIndex].widthRange).length;
                    newMaskRun.widthRange.location += length;
                    newMaskRun.widthRange.length -= length;
                    [templateRunStack popMaskRun];
                    [templateRunStack pushMaskRun:newMaskRun];
                    assert(newMaskRun.widthRange.length > 0);
                }
            } else {
                if (NSLocationInRange(NSMaxRange([templateRunStack currentMaskRun].widthRange) - 1, subtractRunArray[subtractIndex].widthRange)) {
                    // 4.
                    newMaskRun = [templateRunStack currentMaskRun];
                    length = NSIntersectionRange([templateRunStack currentMaskRun].widthRange, subtractRunArray[subtractIndex].widthRange).length;
                    newMaskRun.widthRange.length -= length;
                    [templateRunStack popMaskRun];
                    [templateRunStack pushMaskRun:newMaskRun];
                    assert(newMaskRun.widthRange.length > 0);
                } else {
                    // 3.
                    OSIROIMaskRun originalMaskRun = [templateRunStack currentMaskRun];
                    [templateRunStack popMaskRun];
                    
                    newMaskRun = originalMaskRun;
                    length = NSMaxRange(subtractRunArray[subtractIndex].widthRange) - originalMaskRun.widthRange.location;
                    newMaskRun.widthRange.location += length;
                    newMaskRun.widthRange.length -= length;
                    [templateRunStack pushMaskRun:newMaskRun];
                    assert(newMaskRun.widthRange.length > 0);

                    
                    newMaskRun = originalMaskRun;
                    length = NSMaxRange(originalMaskRun.widthRange) - subtractRunArray[subtractIndex].widthRange.location;
                    newMaskRun.widthRange.length -= length;
                    [templateRunStack pushMaskRun:newMaskRun];
                    assert(newMaskRun.widthRange.length > 0);
                }
            }
        }
    }
    
    while ([templateRunStack count]) {
        [resultMaskRuns addObject:[NSValue valueWithOSIROIMaskRun:[templateRunStack currentMaskRun]]];
        [templateRunStack popMaskRun];
    }

    return [[[OSIROIMask alloc] initWithSortedMaskRuns:resultMaskRuns] autorelease];
}

- (BOOL)intersectsMask:(OSIROIMask *)otherMask // probably could use a faster implementation...
{
    OSIROIMask *intersection = [self ROIMaskByIntersectingWithMask:otherMask];
    return [intersection maskRunCount] > 0;
}

- (BOOL)isEqualToMask:(OSIROIMask *)otherMask // super lazy implementation FIXME!
{
    OSIROIMask *intersection = [self ROIMaskByIntersectingWithMask:otherMask];
    OSIROIMask *subMask1 = [self ROIMaskBySubtractingMask:intersection];
    OSIROIMask *subMask2 = [otherMask ROIMaskBySubtractingMask:intersection];
    
    return [subMask1 maskRunCount] == 0 && [subMask2 maskRunCount] == 0;
}


- (OSIROIMask *)filteredROIMaskUsingPredicate:(NSPredicate *)predicate floatVolumeData:(OSIFloatVolumeData *)floatVolumeData
{
    NSMutableArray *newMaskArray = [NSMutableArray array];
    OSIROIMaskRun activeMaskRun;
    BOOL isMaskRunActive = NO;
    float intensity;
    OSIMaskIndexPredicateStandIn *standIn = [[[OSIMaskIndexPredicateStandIn alloc] init] autorelease];

    for (NSValue *maskRunValue in _maskRuns) {
        OSIROIMaskRun maskRun = [maskRunValue OSIROIMaskRunValue];
        
        OSIROIMaskIndex maskIndex;
        maskIndex.y = maskRun.heightIndex;
        maskIndex.z = maskRun.depthIndex;

        standIn.ROIMaskIntensity = maskRun.intensity;
        standIn.ROIMaskIndexY = maskIndex.y;
        standIn.ROIMaskIndexZ = maskIndex.z;
        
        for (maskIndex.x = maskRun.widthRange.location; maskIndex.x < NSMaxRange(maskRun.widthRange); maskIndex.x++) {
            [floatVolumeData getFloat:&intensity atPixelCoordinateX:maskIndex.x y:maskIndex.y z:maskIndex.z];
            standIn.ROIMaskIndexX = maskIndex.x;
            standIn.intensity = intensity;

            if ([predicate evaluateWithObject:standIn]) {
                if (isMaskRunActive) {
                    activeMaskRun.widthRange.length++;
                } else {
                    activeMaskRun.widthRange.location = maskIndex.x;
                    activeMaskRun.widthRange.length = 1;
                    activeMaskRun.heightIndex = maskIndex.y;
                    activeMaskRun.depthIndex = maskIndex.z;
                    activeMaskRun.intensity = maskRun.intensity;
                    isMaskRunActive = YES;
                }
            } else {
                if (isMaskRunActive) {
                    [newMaskArray addObject:[NSValue valueWithOSIROIMaskRun:activeMaskRun]];
                    isMaskRunActive = NO;
                }
            }
        }
        if (isMaskRunActive) {
            [newMaskArray addObject:[NSValue valueWithOSIROIMaskRun:activeMaskRun]];
            isMaskRunActive = NO;
        }
    }
    
    OSIROIMask *filteredMask = [[[OSIROIMask alloc] initWithSortedMaskRuns:newMaskArray] autorelease];
    [filteredMask checkdebug];
    return filteredMask;
}

- (NSArray *)maskRuns 
{
	return _maskRuns;
}

- (NSData *)maskRunsData
{
    OSIROIMaskRun *maskRunArray;
    NSInteger i;
    
    if (_maskRunsData == nil) {
        maskRunArray = malloc([_maskRuns count] * sizeof(OSIROIMaskRun));
        
        for (i = 0; i < [_maskRuns count]; i++) {
            maskRunArray[i] = [[_maskRuns objectAtIndex:i] OSIROIMaskRunValue];
        }
        
        _maskRunsData = [[NSData alloc] initWithBytesNoCopy:maskRunArray length:[_maskRuns count] * sizeof(OSIROIMaskRun) freeWhenDone:YES];
    }
    
    return _maskRunsData;
}

- (NSUInteger)maskRunCount
{
    return [[self maskRuns] count];
}

- (NSUInteger)maskIndexCount
{
    NSData *maskRunData = [self maskRunsData];
    const OSIROIMaskRun *maskRunArray = [maskRunData bytes];
    NSUInteger maskRunCount = [self maskRunCount];
    NSUInteger maskIndexCount = 0;
    NSUInteger i = 0;
    
    for (i = 0; i < maskRunCount; i++) {
        maskIndexCount += maskRunArray[i].widthRange.length;
    }
    
    return maskIndexCount;
}

- (NSArray *)maskIndexes
{
	NSValue *maskRunValue;
	NSMutableArray *indexes;
    OSIROIMaskRun maskRun;
	
	indexes = [NSMutableArray array];
			   
	for (maskRunValue in _maskRuns) {
        maskRun = [maskRunValue OSIROIMaskRunValue];
        if (maskRun.intensity) {
            [indexes addObjectsFromArray:OSIROIMaskIndexesInRun(maskRun)];
        }
	}
			   
	return indexes;
}

// possibly the slowest implentation I can think of...
- (BOOL)indexInMask:(OSIROIMaskIndex)index
{
	return [[self maskIndexes] containsObject:[NSValue valueWithOSIROIMaskIndex:index]];
}

- (NSArray *)convexHull
{
    NSValue *maskRunValue;
    OSIROIMaskRun maskRun;

    NSInteger maxHeight;
    NSInteger minHeight;
    NSInteger maxDepth;
    NSInteger minDepth;
    NSInteger maxWidth;
    NSInteger minWidth;
    
    for (maskRunValue in _maskRuns) {
        maskRun = [maskRunValue OSIROIMaskRunValue];
        
        maxHeight = MAX(maxHeight, (NSInteger)maskRun.heightIndex + 1);
        minHeight = MIN(minHeight, (NSInteger)maskRun.heightIndex - 1);
        
        maxDepth = MAX(maxDepth, maskRun.depthIndex + 1);
        minDepth = MIN(minDepth, (NSInteger)maskRun.depthIndex - 1);
        
        maxWidth = MAX(maxWidth, (NSInteger)NSMaxRange(maskRun.widthRange) + 1);
        minWidth = MIN(minWidth, (NSInteger)maskRun.widthRange.location - 1);
	}

    NSMutableArray *hull = [NSMutableArray arrayWithCapacity:8];
    [hull addObject:[NSValue valueWithN3Vector:N3VectorMake(minWidth, minDepth, minHeight)]];
    [hull addObject:[NSValue valueWithN3Vector:N3VectorMake(minWidth, maxDepth, minHeight)]];
    [hull addObject:[NSValue valueWithN3Vector:N3VectorMake(maxWidth, maxDepth, minHeight)]];
    [hull addObject:[NSValue valueWithN3Vector:N3VectorMake(maxWidth, minDepth, minHeight)]];
    [hull addObject:[NSValue valueWithN3Vector:N3VectorMake(minWidth, minDepth, maxHeight)]];
    [hull addObject:[NSValue valueWithN3Vector:N3VectorMake(minWidth, maxDepth, maxHeight)]];
    [hull addObject:[NSValue valueWithN3Vector:N3VectorMake(maxWidth, maxDepth, maxHeight)]];
    [hull addObject:[NSValue valueWithN3Vector:N3VectorMake(maxWidth, minDepth, maxHeight)]];
    
    return hull;
}

- (N3Vector)centerOfMass
{
    NSData *maskData = [self maskRunsData];
    NSInteger runCount = [maskData length]/sizeof(OSIROIMaskRun);
    const OSIROIMaskRun *runArray = [maskData bytes];
    NSUInteger i;
    CGFloat floatCount = 0;
    N3Vector centerOfMass = N3VectorZero;
    
    for (i = 0; i < runCount; i++) {
        centerOfMass.x += ((CGFloat)runArray[i].widthRange.location/(CGFloat)runArray[i].widthRange.length) + 0.5;
        centerOfMass.y += (CGFloat)runArray[i].heightIndex/(CGFloat)runArray[i].widthRange.length;
        centerOfMass.z += (CGFloat)runArray[i].depthIndex/(CGFloat)runArray[i].widthRange.length;
        floatCount += runArray[i].widthRange.length;
    }
    
    centerOfMass.x *= floatCount;
    centerOfMass.y *= floatCount;
    centerOfMass.z *= floatCount;
    
    return centerOfMass;
}

- (void)checkdebug
{
#ifndef NDEBUG
    // make sure that all the runs are in order.
    NSInteger i;
    if (_maskRunsData) {
        NSInteger maskRunsDataCount = [_maskRunsData length]/sizeof(OSIROIMaskRun);
        const OSIROIMaskRun *maskRunArray = [_maskRunsData bytes];
        for (i = 0; i < (maskRunsDataCount - 1); i++) {
            assert(OSIROIMaskCompareRun(maskRunArray[i], maskRunArray[i+1]) == NSOrderedAscending);
            assert(OSIROIMaskRunsOverlap(maskRunArray[i], maskRunArray[i+1]) == NO);
        }
        for (i = 0; i < maskRunsDataCount; i++) {
            assert(maskRunArray[i].widthRange.length > 0);
        }
    }
    
    for (i = 0; i < ((NSInteger)[_maskRuns count]) - 1; i++) {
        assert(OSIROIMaskCompareRunValues([_maskRuns objectAtIndex:i], [_maskRuns objectAtIndex:i+1], NULL) == NSOrderedAscending);
        assert(OSIROIMaskRunsOverlap([[_maskRuns objectAtIndex:i] OSIROIMaskRunValue], [[_maskRuns objectAtIndex:i+1] OSIROIMaskRunValue]) == NO);
    }
    for (i = 0; i < [_maskRuns count]; i++) {
        assert([[_maskRuns objectAtIndex:i] OSIROIMaskRunValue].widthRange.length > 0);
    }
#endif
}





@end

@implementation NSValue (OSIMaskRun)

+ (NSValue *)valueWithOSIROIMaskRun:(OSIROIMaskRun)volumeRun
{
	return [NSValue valueWithBytes:&volumeRun objCType:@encode(OSIROIMaskRun)];
}

- (OSIROIMaskRun)OSIROIMaskRunValue
{
	OSIROIMaskRun run;
    assert(strcmp([self objCType], @encode(OSIROIMaskRun)) == 0);
    [self getValue:&run];
    return run;
}	

+ (NSValue *)valueWithOSIROIMaskIndex:(OSIROIMaskIndex)maskIndex
{
	return [NSValue valueWithBytes:&maskIndex objCType:@encode(OSIROIMaskIndex)];
}

- (OSIROIMaskIndex)OSIROIMaskIndexValue
{
	OSIROIMaskIndex index;
    assert(strcmp([self objCType], @encode(OSIROIMaskIndex)) == 0);
    [self getValue:&index];
    return index;
}

@end











