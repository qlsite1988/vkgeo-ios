#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>

#include <ctime>

#include <QtCore/QtGlobal>
#include <QtCore/QString>
#include <QtCore/QDebug>

#include "appinitialized.h"
#include "batteryhelper.h"
#include "vkhelper.h"

#include "locationmanagerdelegate.h"

static const qint64             CENTRAL_LOCATION_CHANGE_TIMEOUT       = 900;
static const NSTimeInterval     LOCATION_ACCURACY_ADJUSTMENT_INTERVAL = 60.0;
static const CLLocationDistance LOCATION_DISTANCE_FILTER              = 100.0,
                                CURRENT_REGION_RADIUS                 = 100.0,
                                CENTRAL_LOCATION_CHANGE_DISTANCE      = 500.0;

static qint64 elapsedNanos()
{
    struct timespec elapsed_time = {};

    if (@available(iOS 10, *)) {
        if (clock_gettime(CLOCK_MONOTONIC_RAW, &elapsed_time) == 0) {
            return static_cast<qint64>(elapsed_time.tv_sec) * 1000000000 + elapsed_time.tv_nsec;
        } else {
            return 0;
        }
    } else {
        assert(0);
    }
}

@implementation LocationManagerDelegate
{
    bool                       CentralLocationChanged;
    qint64                     CentralLocationChangeHandleNanos;
    UIBackgroundTaskIdentifier BackgroundTaskId;
    CLLocation                *CurrentLocation;
    CLCircularRegion          *CurrentRegion API_AVAILABLE(ios(7));
    CLLocation                *CentralLocation;
    CLLocationManager         *LocationManager;
}

- (instancetype)init
{
    self = [super init];

    if (self != nil) {
        CentralLocationChanged           = true;
        CentralLocationChangeHandleNanos = 0;
        BackgroundTaskId                 = UIBackgroundTaskInvalid;
        CurrentLocation                  = nil;
        CurrentRegion                    = nil;
        CentralLocation                  = nil;

        [self requestBackgroundExecution];

        if (@available(iOS 9, *)) {
            LocationManager = [[CLLocationManager alloc] init];

            LocationManager.allowsBackgroundLocationUpdates    = YES;
            LocationManager.pausesLocationUpdatesAutomatically = NO;
            LocationManager.desiredAccuracy                    = kCLLocationAccuracyNearestTenMeters;
            LocationManager.distanceFilter                     = LOCATION_DISTANCE_FILTER;
            LocationManager.delegate                           = self;

            if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusAuthorizedWhenInUse ||
                [CLLocationManager authorizationStatus] == kCLAuthorizationStatusAuthorizedAlways) {
                [LocationManager startUpdatingLocation];

                if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusAuthorizedAlways) {
                    if ([CLLocationManager significantLocationChangeMonitoringAvailable]) {
                        [LocationManager startMonitoringSignificantLocationChanges];
                    }
                }
            }
        } else {
            assert(0);
        }

        [self performSelector:@selector(adjustDesiredAccuracy) withObject:nil afterDelay:LOCATION_ACCURACY_ADJUSTMENT_INTERVAL];
    }

    return self;
}

- (void)dealloc
{
    [CurrentLocation release];
    [CurrentRegion   release];
    [CentralLocation release];
    [LocationManager release];

    [super dealloc];
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations
{
    Q_UNUSED(manager)

    [self requestBackgroundExecution];

    CLLocation *location = locations.lastObject;

    if (CurrentLocation == nil || [CurrentLocation distanceFromLocation:location] > location.horizontalAccuracy) {
        [CurrentLocation release];
        [CurrentRegion   release];

        if (@available(iOS 8, *)) {
            CurrentLocation = [location retain];
            CurrentRegion   = [[CLCircularRegion alloc] initWithCenter:CurrentLocation.coordinate radius:CURRENT_REGION_RADIUS identifier:@"CURRENT_REGION"];

            if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusAuthorizedAlways) {
                if ([CLLocationManager isMonitoringAvailableForClass:[CLCircularRegion class]]) {
                    [LocationManager startMonitoringForRegion:CurrentRegion];
                }
            }

            if (AppInitialized) {
                VKHelper::GetInstance().updateLocation(CurrentLocation.coordinate.latitude, CurrentLocation.coordinate.longitude);
                VKHelper::GetInstance().updateBatteryStatus(BatteryHelper::GetInstance().getBatteryStatus(), BatteryHelper::GetInstance().getBatteryLevel());
            }

            if (CentralLocation == nil || [CentralLocation distanceFromLocation:CurrentLocation] > CENTRAL_LOCATION_CHANGE_DISTANCE) {
                [CentralLocation release];

                CentralLocation        = [CurrentLocation retain];
                CentralLocationChanged = true;
            }
        } else {
            assert(0);
        }
    }
}

- (void)locationManager:(CLLocationManager *)manager didExitRegion:(CLRegion *)region
{
    Q_UNUSED(manager)

    [self requestBackgroundExecution];

    if (CurrentRegion != nil && [CurrentRegion.identifier isEqualToString:region.identifier]) {
        CLLocation *location = LocationManager.location;

        if (location != nil) {
            if (CurrentLocation == nil || [CurrentLocation.timestamp compare:location.timestamp] == NSOrderedAscending) {
                if (@available(iOS 6, *)) {
                    [self locationManager:LocationManager didUpdateLocations:@[location]];
                } else {
                    assert(0);
                }
            }
        }
    }
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
    Q_UNUSED(manager)

    [self requestBackgroundExecution];

    if (@available(iOS 8, *)) {
        if (status == kCLAuthorizationStatusAuthorizedWhenInUse ||
            status == kCLAuthorizationStatusAuthorizedAlways) {
            [LocationManager startUpdatingLocation];

            if (status == kCLAuthorizationStatusAuthorizedAlways) {
                if ([CLLocationManager significantLocationChangeMonitoringAvailable]) {
                    [LocationManager startMonitoringSignificantLocationChanges];
                }

                if (CurrentRegion != nil) {
                    if ([CLLocationManager isMonitoringAvailableForClass:[CLCircularRegion class]]) {
                        [LocationManager startMonitoringForRegion:CurrentRegion];
                    }
                }
            } else {
                [LocationManager stopMonitoringSignificantLocationChanges];

                if (CurrentRegion != nil) {
                    [LocationManager stopMonitoringForRegion:CurrentRegion];
                }
            }
        } else {
            [LocationManager stopUpdatingLocation];
            [LocationManager stopMonitoringSignificantLocationChanges];

            if (CurrentRegion != nil) {
                [LocationManager stopMonitoringForRegion:CurrentRegion];
            }
        }
    } else {
        assert(0);
    }
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    Q_UNUSED(manager)

    [self requestBackgroundExecution];

    qWarning() << QString::fromNSString(error.localizedDescription);
}

- (void)locationManager:(CLLocationManager *)manager monitoringDidFailForRegion:(CLRegion *)region withError:(NSError *)error
{
    Q_UNUSED(manager)
    Q_UNUSED(region)

    [self requestBackgroundExecution];

    qWarning() << QString::fromNSString(error.localizedDescription);
}

- (void)adjustDesiredAccuracy
{
    [self requestBackgroundExecution];

    if (CentralLocationChanged) {
        LocationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters;

        CentralLocationChanged           = false;
        CentralLocationChangeHandleNanos = elapsedNanos();
    } else if (elapsedNanos() - CentralLocationChangeHandleNanos > CENTRAL_LOCATION_CHANGE_TIMEOUT * 1000000000) {
        LocationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters;
    }

    [self performSelector:@selector(adjustDesiredAccuracy) withObject:nil afterDelay:LOCATION_ACCURACY_ADJUSTMENT_INTERVAL];
}

- (void)requestBackgroundExecution
{
    UIBackgroundTaskIdentifier prev_bg_task_id = BackgroundTaskId;

    BackgroundTaskId = [UIApplication.sharedApplication beginBackgroundTaskWithExpirationHandler:^(void) {
        if (BackgroundTaskId != UIBackgroundTaskInvalid) {
            [UIApplication.sharedApplication endBackgroundTask:BackgroundTaskId];

            BackgroundTaskId = UIBackgroundTaskInvalid;
        }
    }];

    if (prev_bg_task_id != UIBackgroundTaskInvalid) {
        [UIApplication.sharedApplication endBackgroundTask:prev_bg_task_id];
    }
}

@end
