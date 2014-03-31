//
//  SLWay.m
//  Speed Limit
//
//  Created by Abhi Beckert on 27/03/2014.
//  Copyright (c) 2014 Abhi Beckert. All rights reserved.
//

#import "SLWay.h"

@interface SLWay () {
  NSUInteger coordCount;
  CLLocationCoordinate2D *coords;
}

@property NSUInteger wayId;
@property (strong) NSString *name;
@property NSUInteger speedLimit;

@end

@implementation SLWay

- (void)encodeWithCoder:(NSCoder *)coder
{
  unsigned long wayId = self.wayId;
  [coder encodeBytes:(void *)&wayId length:sizeof(wayId)];
  
  [coder encodeObject:self.name];
  
  unsigned long speed = self.speedLimit;
  [coder encodeBytes:(void *)&speed length:sizeof(speed)];
  
  [coder encodeObject:self.nodes];
}

- (id)initWithCoder:(NSCoder *)decoder
{
  unsigned long wayId = *(unsigned long *)([decoder decodeBytesWithReturnedLength:NULL]);
  
  NSString *name = [decoder decodeObject];
  
  unsigned long speed = *(unsigned long *)([decoder decodeBytesWithReturnedLength:NULL]);
  
  NSArray *nodes = [decoder decodeObject];
  
  return [self initWithWayID:wayId name:name speedLimit:speed nodes:nodes];
}

- (void)dealloc
{
  free(coords);
}

- (instancetype)initWithWayID:(NSUInteger)wayId name:(NSString *)name speedLimit:(NSUInteger)speed nodes:(NSArray *)nodes
{
  if (!(self = [super init]))
    return nil;
  
  self.wayId = wayId;
  self.name = name;
  self.speedLimit = speed;
  
  coordCount = nodes.count;
  NSUInteger nodeIndex;
  coords = malloc(coordCount * sizeof(CLLocationCoordinate2D));
  for (nodeIndex = 0; nodeIndex < coordCount; nodeIndex++) {
    coords[nodeIndex] = CLLocationCoordinate2DMake([nodes[nodeIndex][0] doubleValue], [nodes[nodeIndex][1] doubleValue]);
  }
  
  return self;
}

- (NSString *)description
{
  return [NSString stringWithFormat:@"<SLWay> %@", [self dictionaryWithValuesForKeys:@[@"wayId", @"name", @"speedLimit", @"nodes"]]];
}

- (NSArray *)nodes
{
  NSMutableArray *nodes = @[].mutableCopy;
  NSUInteger nodeIndex = 0;
  for (nodeIndex = 0; nodeIndex < coordCount; nodeIndex++) {
    [nodes addObject:@[[NSNumber numberWithFloat:coords[nodeIndex].latitude], [NSNumber numberWithFloat:coords[nodeIndex].longitude]]];
  }
  
  return nodes.copy;
}

- (BOOL)matchesLocation:(CLLocationCoordinate2D)location trail:(NSArray *)locations
{
  static CLLocationCoordinate2D invalidCoord = (CLLocationCoordinate2D){200, 200};
  
  NSUInteger nodeIndex = 0;
  
  if (coordCount == 1)
    return NO; // not a valid way, and will screw up our search algorithm
  
  for (nodeIndex = 0; nodeIndex < coordCount; nodeIndex++) {
    // load nodes
    CLLocationCoordinate2D nodeCoord = coords[nodeIndex];
    
    BOOL hasPrevNode = (nodeIndex > 0);
    CLLocationCoordinate2D prevNodeCoord = hasPrevNode ? coords[nodeIndex - 1] : invalidCoord;
    
    BOOL hasNextNode = (nodeIndex + 1 < coordCount);
    CLLocationCoordinate2D nextNodeCoord = hasNextNode ? coords[nodeIndex + 1] : invalidCoord;
    
    
    // check distance
    CLLocationDistance distanceToCurrent = distanceToCoord(nodeCoord, location);
    
    if (distanceToCurrent > 10000)
      return NO; // give up on this way
    
    if (distanceToCurrent > 100)
      continue; // move to the next node
    
    if (hasNextNode && hasPrevNode) {
      CLLocationDistance distanceToNext = distanceToCoord(nodeCoord, nextNodeCoord);
      CLLocationDistance distanceToPrev = distanceToCoord(nodeCoord, prevNodeCoord);
      if (distanceToNext < (distanceToCurrent + 5) && distanceToPrev < (distanceToCurrent + 5))
        continue;
    } else if (hasNextNode) {
      CLLocationDistance distanceToNext = distanceToCoord(nodeCoord, nextNodeCoord);
      if (distanceToNext < (distanceToCurrent + 5))
        continue;
    } else if (hasPrevNode) {
      CLLocationDistance distanceToPrev = distanceToCoord(nodeCoord, prevNodeCoord);
      if (distanceToPrev < (distanceToCurrent + 5))
        continue;
    }
    
    // check bearing
    double bearingToCurrent = bearingToCoord(nodeCoord, location);
    if (hasNextNode & hasPrevNode) {
      double bearingToNext = bearingToCoord(nodeCoord, nextNodeCoord);
      double bearingToPrev = bearingToCoord(nodeCoord, prevNodeCoord);
      double bearingDifference = MIN(fabs(bearingToCurrent - bearingToNext), fabs(bearingToCurrent - bearingToPrev));
      
      if (bearingDifference > 15)
        continue;
    } else if (hasNextNode) {
      double bearingToNext = bearingToCoord(nodeCoord, nextNodeCoord);
      double bearingDifference = fabs(bearingToCurrent - bearingToNext);
      
      if (bearingDifference > 15)
        continue;
    } else if (hasPrevNode) {
      double bearingToPrev = bearingToCoord(nodeCoord, prevNodeCoord);
      double bearingDifference = fabs(bearingToCurrent - bearingToPrev);
      
      if (bearingDifference > 15)
        continue;
    }
    
    return YES;
  }
  
  return NO;
}

@end