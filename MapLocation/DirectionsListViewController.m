//
//  DirectionsListViewController.m
//  FlyMeThere
//
//  Created by Matt Galloway on 23/06/2013.
//  Copyright (c) 2013 Matt Galloway. All rights reserved.
//

#import "DirectionsListViewController.h"

#import "Route.h"
#import "Airport.h"
#import "MapKitHelpers.h"

@import MapKit;

@interface DirectionsListViewController ()
@end

@implementation DirectionsListViewController {
    NSMutableDictionary * _snapshots;
}

#pragma mark -

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    _tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 44, [UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height)];
    _tableView.delegate = self;
    _tableView.dataSource = self;
    [self.view addSubview:_tableView];
}


#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case 0:
            return _route.toSourceAirportRoute.steps.count; break;
        case 1:
            return 1; break;
        case 2:
            return _route.fromDestinationAirportRoute.steps.count; break;
    }
    return 0;
}

- (NSString*)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case 0:
            return @"To Airport"; break;
        case 1:
            return @"Flight"; break;
        case 2:
            return @"From Airport"; break;
    }
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *CellIdentifier = [NSString stringWithFormat:@"cell%li%li", (long)indexPath.section, (long)indexPath.row];
    
    UITableViewCell *cell =  [_tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
        cell.imageView.image = nil;
        
        MKRouteStep *step = nil;
        
        switch (indexPath.section) {
            case 0: {
                step = _route.toSourceAirportRoute.steps[indexPath.row];
            }
                break;
            case 1: {
                cell.textLabel.text = [NSString stringWithFormat:@"Fly from '%@' to '%@'", _route.sourceAirport.name, _route.destinationAirport.name];
                cell.detailTextLabel.text = nil;
            }
                break;
            case 2: {
                step = _route.fromDestinationAirportRoute.steps[indexPath.row];
            }
                break;
        }
        
        if (step) {
            cell.textLabel.text = step.instructions;
            cell.detailTextLabel.text = step.notice;
            
            UIImage *cachedSnapshot = _snapshots[indexPath];
            if (cachedSnapshot) {
                cell.imageView.image = cachedSnapshot;
            } else {
                [self loadSnapshotForCellAtIndex:indexPath];
            }
        }

    }
    
    return cell;
}

- (void) loadSnapshotForCellAtIndex:(NSIndexPath *) indexPath {
    MKRouteStep * step = nil;
    switch (indexPath.section) {
        case 0:{
            step = _route.toSourceAirportRoute.steps[indexPath.row];
        }
            break;
        case 2: {
            step = _route.fromDestinationAirportRoute.steps[indexPath.row];
        }
            break;
        default:
            break;
    }
    
    if (step) {
        MKMapSnapshotOptions * options = [[MKMapSnapshotOptions alloc] init];
        options.scale = [[UIScreen mainScreen] scale];
        options.region = CoordinateRegionBoundingMapPoints(step.polyline.points, step.polyline.pointCount);
        options.size = CGSizeMake(44.0f, 44.0f);
        
        MKMapSnapshotter * snapshotter = [[MKMapSnapshotter alloc] initWithOptions:options];
        [snapshotter startWithCompletionHandler:^(MKMapSnapshot *snapshot, NSError *error) {
            if (!error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    UITableViewCell * cell = [_tableView cellForRowAtIndexPath:indexPath];
                    if (cell) {
                        cell.imageView.image = snapshot.image;
                        [cell setNeedsDisplay];
                    }
                    _snapshots[indexPath] = snapshot.image;
                });
            }
        }];
    }
}

@end
