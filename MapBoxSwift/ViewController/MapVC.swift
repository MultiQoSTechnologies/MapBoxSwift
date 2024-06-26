//
//  ViewController.swift
//  MaxBoxDemo
//
//  Created by MQF-6 on 20/06/24.
//

import UIKit
import MapboxMaps
import Combine
import MapboxSearch
import MapboxSearchUI
import MapboxDirections

struct DirectionRoute {
    var pickup: CLLocationCoordinate2D?
    var drop: CLLocationCoordinate2D?
}


class MapVC: UIViewController {
    
    @IBOutlet weak var mapView: MapView!
    @IBOutlet weak var btnDownload: UIButton!
    @IBOutlet weak var btnDirection: UIButton!
    @IBOutlet weak var btnOfflineMap: UIButton!
    @IBOutlet weak var lblProgress: UILabel!
    
    var cancellable = Set<AnyCancellable>()
    var selectedAddress: ((SearchResult) -> Void)?
    var annotationManager: PointAnnotationManager?
    var polylineManager: PolylineAnnotationManager?
    
    var pickLocations = false
    var directionRoute: DirectionRoute? = DirectionRoute()
     
    
    override func viewDidLoad() {
        super.viewDidLoad()
        addMapView()
        showSearchOption()
        addMarkerOnTap()
        
        btnDownload.setCorner()
        btnDownload.setShadow()
        btnOfflineMap.setCorner()
        btnOfflineMap.setShadow()
        btnDirection.setCorner()
        btnDirection.setShadow()
    }
     
    
    private func downloadOfflineMap() {
        
        self.view.showLoader()
        lblProgress.isHidden = false
        
        let offlineManager = OfflineManager()
        
        let bounds: [String: Any] = [
            "southwest_latitude": 22.9646,
            "southwest_longitude": 72.4455,
            "northeast_latitude": 23.1252,
            "northeast_longitude": 72.6808
        ]
        
        let options = TilesetDescriptorOptions(
            styleURI: .outdoors, zoomRange: 0...16, tilesets: []
        )
        
        let tilesetDescriptor = offlineManager.createTilesetDescriptor(for: options)
        
        let tileRegionLoadOptions = TileRegionLoadOptions(
            geometry: .polygon(Polygon([[LocationCoordinate2D(latitude: 22.9646, longitude: 72.4455), LocationCoordinate2D(latitude: 23.1252, longitude: 72.6808)]])),
            descriptors: [tilesetDescriptor],
            acceptExpired: false,
            extraOptions: options
        )
        
        TileStore.default.loadTileRegion(
            forId: "ahmedabad-region",
            loadOptions: tileRegionLoadOptions!
        ) { progress in
            print("Progress: \(progress.completedResourceCount) / \(progress.requiredResourceCount)")
            DispatchQueue.main.async {
                self.lblProgress.text = "Downloading.... \(progress.completedResourceCount) / \(progress.requiredResourceCount)"
            }
            
        } completion: { result in
            DispatchQueue.main.async {
                self.view.hideLoader()
                self.lblProgress.isHidden = true
            }
            
            switch result {
            case .success(let region):
                print("Offline pack downloaded successfully: \(region.id)")
                UserDefaults.standard.setValue(bounds, forKey: region.id)
                
            case .failure(let error):
                print("Failed to download offline pack: \(error.localizedDescription)")
            }
        }
    }
    
    private func getAllDownloadedMap() {
        TileStore.default.allTileRegions { result in
            switch result {
            case .success(let tileRegions):
                for region in tileRegions {
                    print(region.id)
                }
            case .failure(let error):
                print("Failed to fetch offline regions: \(error.localizedDescription)")
            }
        }
    }
    
    private func removeAllOfflineRegions() {
        TileStore.default.allTileRegions { result in
            switch result {
            case .success(let tileRegions):
                let group = DispatchGroup()
                
                for region in tileRegions {
                    group.enter()
                    TileStore.default.removeRegion(forId: region.id) { result in
                        switch result {
                        case .success(let region):
                            print("Region removed successfully")
                            
                        case .failure(let failure):
                            print("Error in removing region")
                        }
                    }
                }
                
                group.notify(queue: .main) {
                    print("All offline regions have been removed.")
                }
                
            case .failure(let error):
                print("Failed to fetch offline regions: \(error.localizedDescription)")
            }
        }
    }
    
    private func drawRoute(coordinates: [LocationCoordinate2D]) {
        let routeOptions = RouteOptions(coordinates: coordinates)
        
        _ = Directions.shared.calculate(routeOptions) { (session, result) in
            
            switch result {
            case .failure(let error):
                self.popupAlert(title: "Error", message: error.localizedDescription, actionTitles: ["Okay"], actions: [{action in}])
            case .success(let response):
                guard let route = response.routes?.first else { return }
                
                var polylineAnnotation = [PolylineAnnotation]()
                
                var lineAnnotation = PolylineAnnotation(lineString: route.shape!)
                lineAnnotation.lineWidth = 3.0
                lineAnnotation.lineColor = StyleColor.init(.blue)
                
                polylineAnnotation.append(lineAnnotation)
                
                let lineAnnnotationManager = self.mapView.annotations.makePolylineAnnotationManager()
                
                lineAnnnotationManager.annotations = polylineAnnotation
                
                self.directionRoute = nil
            }
        }
    }
    
    private func focusCameraOnBounds(bounds: [String: Any]) {
        guard let mapView = self.mapView else { return }
        
        let southwestLatitude = bounds["southwest_latitude"] as? Double ?? 0.0
        let southwestLongitude = bounds["southwest_longitude"] as? Double ?? 0.0
        let northeastLatitude = bounds["northeast_latitude"] as? Double ?? 0.0
        let northeastLongitude = bounds["northeast_longitude"] as? Double ?? 0.0
        
        let southwest = CLLocationCoordinate2D(latitude: southwestLatitude, longitude: southwestLongitude)
        let northeast = CLLocationCoordinate2D(latitude: northeastLatitude, longitude: northeastLongitude)
        
        let cameraOptions = try! mapView.mapboxMap.camera(for: [southwest, northeast], camera: CameraOptions(), coordinatesPadding: UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20), maxZoom: 16, offset: nil)
        
        mapView.camera.fly(to: cameraOptions)
        
        drawPolygonAroundBounds(
            southwest: southwest,
            northeast: northeast
        )
    }
    
    
    private func loadOfflineMap() {
        TileStore.default.tileRegion(forId: "ahmedabad-region") { result in
            switch result {
                
            case .success(let region):
                guard let boundObj = UserDefaults.standard.value(forKey: region.id) as? [String: Any] else {
                    return
                }
                
                self.focusCameraOnBounds(bounds: boundObj)
                
            case .failure(let error):
                self.popupAlert(title: "Error", message: "No offline map found", actionTitles: ["Okay"], actions: [{ action in
                    
                }])
                print("Failed to load offline region: \(error.localizedDescription)")
            }
        }
    }
    
    private func showSearchOption() {
        let searchController = MapboxSearchController()
        searchController.delegate = self
        searchController.configuration = Configuration(allowsFeedbackUI: true, locationProvider: nil, hideCategorySlots: true, style: .default)
        let panelController = MapboxPanelController(rootViewController: searchController)
        
        addChild(panelController)
    }
    
    private func addMapView() {
        let lastLocation = LocationHelper.shared.lastLocation ?? CLLocation(latitude: 23.04842896879802, longitude: 72.5249321610303)
        let cameraOptions = CameraOptions(center: lastLocation.coordinate, zoom: 16, bearing: 0, pitch: 0)
        mapView.mapboxMap.setCamera(to: cameraOptions)
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    }
    
    private func addMarker(coordinate: CLLocationCoordinate2D, image: String = "ic_pin") {
        var pointAnnotation = PointAnnotation(coordinate: coordinate)
        pointAnnotation.image = .init(image: UIImage(named: image)!, name: image)
        annotationManager = mapView.annotations.makePointAnnotationManager()
        annotationManager?.annotations = [pointAnnotation]
        mapView.camera.fly(to: CameraOptions(cameraState: .init(center: coordinate, padding: .init(), zoom: 10, bearing: 0, pitch: 0)))
        checkDrawRoute(coordinate: coordinate)
    }
    
    private func checkDrawRoute(coordinate: CLLocationCoordinate2D) {
        if pickLocations {
            if directionRoute?.pickup == nil {
                directionRoute = DirectionRoute()
                directionRoute?.pickup = coordinate
            } else {
                directionRoute?.drop = coordinate
                pickLocations = false
                
                drawRoute(coordinates: [directionRoute!.pickup!, directionRoute!.drop!])
            }
        }
    }
    
    private func addMarkerOnTap() {
        mapView.gestures.onMapTap.receive(on: RunLoop.main)
            .sink { [weak self] context in
                guard let `self` = self else {
                    return
                }
                
                addMarker(coordinate: context.coordinate)
            }
            .store(in: &cancellable)
    }
    
    private func removeAllMarkers() {
        annotationManager?.annotations.removeAll()
    }
    
    private func drawPolygonAroundBounds(southwest: CLLocationCoordinate2D, northeast: CLLocationCoordinate2D) {
        guard let mapView = self.mapView else { return }
        
        let coordinates = [
            southwest,
            CLLocationCoordinate2D(latitude: southwest.latitude, longitude: northeast.longitude),
            northeast,
            CLLocationCoordinate2D(latitude: northeast.latitude, longitude: southwest.longitude),
            southwest
        ]
        
        let polygonAnnotationManager = mapView.annotations.makePolygonAnnotationManager()
        
        var polygon = PolygonAnnotation(polygon: Polygon([coordinates]))
        polygon.fillColor = StyleColor(.red) // Customize the fill color and opacity)
        polygon.fillOpacity = 0.5
        polygon.fillOutlineColor = StyleColor(.red)
        polygonAnnotationManager.annotations = [polygon]
    }
    
    
    private func showAnnotations(results: [SearchResult]) {
        removeAllMarkers()
        let annotations = results.map { searchResult -> PointAnnotation in
            var pointAnnotation = PointAnnotation(coordinate: searchResult.coordinate)
            pointAnnotation.image = .init(image: UIImage(named: "ic_pin")!, name: "ic_pin")
            annotationManager = mapView.annotations.makePointAnnotationManager()
            return pointAnnotation
        }
        
        annotationManager?.annotations = annotations
        
        if case let .point(point) = annotations.first?.geometry {
            let options = CameraOptions(center: point.coordinates)
            mapView?.mapboxMap.setCamera(to: options)
        }
    }
    
    private func setCamera(coordinates: CLLocationCoordinate2D) {
        let cameraOptions = CameraOptions(center: coordinates, zoom: 16, bearing: 0, pitch: 0)
        mapView.mapboxMap.setCamera(to: cameraOptions)
    }
    
    
}

extension MapVC {
    @IBAction private func btnDownloadAction(_ sender: UIButton) {
        downloadOfflineMap()
    }
    
    @IBAction private func btnViewOfflineAction(_ sender: UIButton) {
        loadOfflineMap()
    }
     
    @IBAction private func btnDirectionAction(_ sender: UIButton) {
        if !pickLocations {
            popupAlert(title: "Alert", message: "Tap on map to select start and end location for direction.", actionTitles: ["Okay"], actions: [{ action in
                self.pickLocations = true
            }])
        }
    }
}

extension MapVC: SearchControllerDelegate {
    
    func searchResultSelected(_ searchResult: any MapboxSearch.SearchResult) {
        addMarker(coordinate: searchResult.coordinate)
    }
    
    func categorySearchResultsReceived(category: MapboxSearchUI.SearchCategory, results: [any MapboxSearch.SearchResult]) {
        showAnnotations(results: results)
    }
    
    func userFavoriteSelected(_ userFavorite: MapboxSearch.FavoriteRecord) {
        addMarker(coordinate: userFavorite.coordinate, image: userFavorite.id == "home" ? "ic_home" : userFavorite.id == "work" ? "ic_work" : "ic_fav")
    }
    
    func shouldCollapseForSelection(_ searchResult: any MapboxSearch.SearchResult) -> Bool {
        return true
    }
}
