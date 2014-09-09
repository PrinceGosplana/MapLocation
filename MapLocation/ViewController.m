//
//  ViewController.m
//  MapLocation
//
//  Created by Administrator on 03.09.14.
//  Copyright (c) 2014 Administrator. All rights reserved.
//

#import "ViewController.h"
#import "DirectionsListViewController.h"

#import "Airport.h"
#import "Route.h"
#import "MapKitHelpers.h"

@import MapKit;

typedef void (^LocationCallback)(CLLocationCoordinate2D);

@interface ViewController () < MKMapViewDelegate, UISearchBarDelegate, UIActionSheetDelegate>

@property (nonatomic, strong) MKMapView * mapView;
@property (nonatomic, strong) UISearchBar * searchBar;

@end

@implementation ViewController {
    NSArray *_airports;
    NSArray *_foundMapItems;
    LocationCallback _foundLocationCallback;
    Route *_route;
}


- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.title = @"Map location";
    
    _mapView = [[MKMapView alloc] initWithFrame:self.view.frame];
    _mapView.delegate = self;
    _mapView.showsUserLocation = YES;
    _mapView.pitchEnabled = YES;
    [self.view addSubview:_mapView];
    
    _searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 64, [UIScreen mainScreen].bounds.size.width, 44)];
    _searchBar.delegate = self;
    [self.view addSubview:_searchBar];
    
    [self loadAirportData];
    self.navigationController.toolbarHidden = YES;
    
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender {
    if ([identifier isEqualToString:@"List"]) {
        return _route != nil;
    }
    return YES;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"List"]) {
        DirectionsListViewController *vc = (DirectionsListViewController*)segue.destinationViewController;
        vc.route = _route;
    }
}


#pragma mark -

- (void)loadAirportData {
    NSMutableArray *airports = [NSMutableArray new];
    
    NSURL *dataFileURL = [[NSBundle mainBundle] URLForResource:@"airports" withExtension:@"csv"];
    
    NSString *data = [NSString stringWithContentsOfURL:dataFileURL encoding:NSUTF8StringEncoding error:nil];
    
    NSCharacterSet *quotesCharacterSet = [NSCharacterSet characterSetWithCharactersInString:@"\""];
    
    NSScanner *scanner = [[NSScanner alloc] initWithString:data];
    BOOL ok = YES;
    BOOL firstLine = YES;
    while (![scanner isAtEnd] && ok) {
        NSString *line = nil;
        ok = [scanner scanUpToString:@"\n" intoString:&line];
        
        if (firstLine) {
            firstLine = NO;
            continue;
        }
        
        if (line && ok) {
            NSArray *components = [line componentsSeparatedByString:@","];
            
            NSString *type = [components[2] stringByTrimmingCharactersInSet:quotesCharacterSet];
            if ([type isEqualToString:@"large_airport"]) {
                Airport *airport = [Airport new];
                airport.name = [components[3] stringByTrimmingCharactersInSet:quotesCharacterSet];
                airport.city = [components[10] stringByTrimmingCharactersInSet:quotesCharacterSet];
                airport.code = [components[13] stringByTrimmingCharactersInSet:quotesCharacterSet];
                airport.location = [[CLLocation alloc] initWithLatitude:[components[4] doubleValue]
                                                              longitude:[components[5] doubleValue]];
                
                [airports addObject:airport];
            }
        }
    }
    
    _airports = airports;
}

- (void)startSearchForText:(NSString*)searchText {
    // 1
    [_searchBar resignFirstResponder];
    _searchBar.userInteractionEnabled = NO;
    
    // 2
    MKLocalSearchRequest *searchRequest = [[MKLocalSearchRequest alloc] init];
    searchRequest.naturalLanguageQuery = searchText;
    
    // 3
    MKLocalSearch *search = [[MKLocalSearch alloc] initWithRequest:searchRequest];
    [search startWithCompletionHandler:^(MKLocalSearchResponse *response, NSError *error) {
        if (response.mapItems.count > 0) {
            // 4
            UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:@"Select a location"
                                                                     delegate:self
                                                            cancelButtonTitle:nil
                                                       destructiveButtonTitle:nil
                                                            otherButtonTitles:nil];
            [response.mapItems enumerateObjectsUsingBlock:^(MKMapItem *mapItem, NSUInteger idx, BOOL *stop) {
                [actionSheet addButtonWithTitle:mapItem.placemark.title];
            }];
            
            [actionSheet addButtonWithTitle:@"Cancel"];
            actionSheet.cancelButtonIndex = actionSheet.numberOfButtons - 1;
            
            // 5
            _foundMapItems = [response.mapItems copy];
            [actionSheet showInView:self.view];
        } else {
            // 6
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Oops!"
                                                            message:@"No search results found! Try again with a different query."
                                                           delegate:nil
                                                  cancelButtonTitle:nil
                                                  otherButtonTitles:@"OK", nil];
            [alert show];
            
            _searchBar.userInteractionEnabled = YES;
        }
    }];
}

- (MKMapItem*)mapItemForCoordinate:(CLLocationCoordinate2D)coordinate {
    MKPlacemark *placemark = [[MKPlacemark alloc] initWithCoordinate:coordinate addressDictionary:nil];
    MKMapItem *mapItem = [[MKMapItem alloc] initWithPlacemark:placemark];
    return mapItem;
}

- (void)performAfterFindingLocation:(LocationCallback)callback {
    if (self.mapView.userLocation != nil) {
        if (callback) {
            callback(self.mapView.userLocation.coordinate);
        }
    } else {
        _foundLocationCallback = [callback copy];
    }
}

- (Airport*)nearestAirportToCoordinate:(CLLocationCoordinate2D)coordinate {
    __block Airport *nearestAirport = nil;
    __block CLLocationDistance nearestDistance = DBL_MAX;
    
    CLLocation *coordinateLocation = [[CLLocation alloc] initWithLatitude:coordinate.latitude longitude:coordinate.longitude];
    
    [_airports enumerateObjectsUsingBlock:^(Airport *airport, NSUInteger idx, BOOL *stop) {
        CLLocationDistance distance = [coordinateLocation distanceFromLocation:airport.location];
        if (distance < nearestDistance) {
            nearestAirport = airport;
            nearestDistance = distance;
        }
    }];
    
    return nearestAirport;
}


#pragma mark - MKMapViewDelegate

- (MKAnnotationView*)mapView:(MKMapView *)mapView viewForAnnotation:(id<MKAnnotation>)annotation {
    if ([annotation isKindOfClass:[MKPlacemark class]]) {
        MKPinAnnotationView *pin = (MKPinAnnotationView*)[mapView dequeueReusableAnnotationViewWithIdentifier:@"placemark"];
        if (!pin) {
            pin = [[MKPinAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:@"placemark"];
            pin.pinColor = MKPinAnnotationColorRed;
            pin.canShowCallout = YES;
        } else {
            pin.annotation = annotation;
        }
        return pin;
    }
    return nil;
}

- (void)mapView:(MKMapView *)mapView didUpdateUserLocation:(MKUserLocation *)userLocation {
    if (_foundLocationCallback) {
        _foundLocationCallback(userLocation.coordinate);
        _foundLocationCallback = nil;
    }
}


#pragma mark - UISearchBarDelegate

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [self startSearchForText:searchBar.text];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
}

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar {
    searchBar.showsCancelButton = YES;
}

- (void)searchBarTextDidEndEditing:(UISearchBar *)searchBar {
    searchBar.showsCancelButton = NO;
}


#pragma mark - UIActionSheetDelegate

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex != actionSheet.cancelButtonIndex) {
        MKMapItem *item = _foundMapItems[buttonIndex];
        NSLog(@"Selected item: %@", item);
        [self calculateRouteToMapItem:item];
    } else {
        _searchBar.userInteractionEnabled = YES;
    }
}

- (void) setupWithNewRoute:(Route *) route {
    if (_route) {
        [_mapView removeAnnotations:@[_route.source,
                                      _route.destination,
                                      _route.sourceAirport,
                                      _route.destinationAirport]];
        [_mapView removeOverlays:@[_route.flyPartPolyline]];
        _route = nil;
    }
    _route = route;
    
    [_mapView addAnnotations:@[route.source,
                               route.destination,
                               route.sourceAirport,
                               route.destinationAirport]];
    [_mapView addOverlay:route.flyPartPolyline level:MKOverlayLevelAboveRoads];
    
    MKMapPoint points[4];
    points[0] = MKMapPointForCoordinate(route.source.coordinate);
    points[1] = MKMapPointForCoordinate(route.destination.coordinate);
    points[2] = MKMapPointForCoordinate(route.sourceAirport.coordinate);
    points[3] = MKMapPointForCoordinate(route.destinationAirport.coordinate);
    
    MKMapPointForCoordinate(route.destinationAirport.coordinate);
    
    MKCoordinateRegion boundingRegion = CoordinateRegionBoundingMapPoints(points, 4);
    boundingRegion.span.latitudeDelta *= 1.1f;
    boundingRegion.span.longitudeDelta *= 1.1f;
    [_mapView setRegion:boundingRegion animated:YES];

}

- (void) calculateRouteToMapItem: (MKMapItem *) item {
    [self performAfterFindingLocation:^(CLLocationCoordinate2D userLocation) {
        MKPointAnnotation * sourceAnnotation = [MKPointAnnotation new];
        sourceAnnotation.coordinate = userLocation;
        sourceAnnotation.title = @"Start";
        
        MKPointAnnotation * destinationAnnotation = [MKPointAnnotation new];
        destinationAnnotation.coordinate = item.placemark.coordinate;
        destinationAnnotation.title = @"End";
        
        // 3
        Airport * sourceAirport = [self nearestAirportToCoordinate:userLocation];
        Airport * destinationAirport = [self nearestAirportToCoordinate:item.placemark.coordinate];
        
        Route * route = [Route new];
        route.source = sourceAnnotation;
        route.destination = destinationAnnotation;
        route.sourceAirport = sourceAirport;
        route.destinationAirport = destinationAirport;
        
        // 5
        CLLocationCoordinate2D coords[2] = { sourceAirport.coordinate, destinationAirport.coordinate};
        route.flyPartPolyline = [MKGeodesicPolyline polylineWithCoordinates:coords count:2];
        
        // 6
        [self setupWithNewRoute:route];
        
        // 7
        _searchBar.userInteractionEnabled = YES;
    }];
}

- (MKOverlayRenderer *) mapView:(MKMapView *)mapView rendererForOverlay:(id<MKOverlay>)overlay {
    if ([overlay isKindOfClass:[MKPolyline class]]) {
        MKPolylineRenderer * renderer = [[MKPolylineRenderer alloc] initWithPolyline:(MKPolyline *) overlay];
        
        if (overlay == _route.flyPartPolyline) {
            renderer.strokeColor = [UIColor redColor];
        } else {
            renderer.strokeColor = [UIColor blueColor];
        }
        return renderer;
    }
    return nil;
}

@end
