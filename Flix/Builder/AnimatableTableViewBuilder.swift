//
//  AnimatableTableViewBuilder.swift
//  Flix
//
//  Created by DianQK on 04/10/2017.
//  Copyright © 2017 DianQK. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import RxDataSources

public class AnimatableTableViewBuilder: _TableViewBuilder {
    
    typealias AnimatableSectionModel = RxDataSources.AnimatableSectionModel<IdentifiableSectionNode, IdentifiableNode>
    
    let disposeBag = DisposeBag()
    let delegeteProxy = TableViewDelegateProxy()
    
    let tableView: UITableView
    
    public let sectionProviders: Variable<[AnimatableTableViewSectionProvider]>
    
    var nodeProviders: [_TableViewMultiNodeProvider] = [] {
        didSet {
            for provider in nodeProviders {
                provider.register(tableView)
            }
        }
    }
    var footerSectionProviders: [_SectionPartionTableViewProvider] = [] {
        didSet {
            for provider in footerSectionProviders {
                provider.register(tableView)
            }
        }
    }
    var headerSectionProviders: [_SectionPartionTableViewProvider] = [] {
        didSet {
            for provider in headerSectionProviders {
                provider.register(tableView)
            }
        }
    }

    public init(tableView: UITableView, sectionProviders: [AnimatableTableViewSectionProvider]) {
        
        self.tableView = tableView
        self.sectionProviders = Variable(sectionProviders)
        
        let dataSource = RxTableViewSectionedAnimatedDataSource<AnimatableSectionModel>(configureCell: { [weak self] dataSource, tableView, indexPath, node in
            guard let provider = self?.nodeProviders.first(where: { $0._flix_identity == node.providerIdentity }) else { return UITableViewCell() }
            return provider._configureCell(tableView, indexPath: indexPath, node: node)
        })
        
        dataSource.animationConfiguration = AnimationConfiguration(
            insertAnimation: .fade,
            reloadAnimation: .none,
            deleteAnimation: .fade
        )
        
        self.build(dataSource: dataSource)
        
        self.sectionProviders.asObservable()
            .do(onNext: { [weak self] (sectionProviders) in
                self?.nodeProviders = sectionProviders.flatMap { $0.animatableProviders }
                self?.footerSectionProviders = sectionProviders.flatMap { $0.animatableFooterProvider }
                self?.headerSectionProviders = sectionProviders.flatMap { $0.animatableHeaderProvider }
            })
            .flatMapLatest { (providers) -> Observable<[AnimatableSectionModel]> in
                let sections: [Observable<(section: IdentifiableSectionNode, nodes: [IdentifiableNode])?>] = providers.map { $0.genteralAnimatableSectionModel() }
                return Observable.combineLatest(sections)
                    .ifEmpty(default: [])
                    .map { value -> [AnimatableSectionModel] in
                        return value.flatMap { $0 }.enumerated()
                            .map { (offset, section) -> AnimatableSectionModel in
                                let items = section.nodes.map { (node) -> IdentifiableNode in
                                    var node = node
                                    node.providerStartIndexPath.section = offset
                                    node.providerEndIndexPath.section = offset
                                    return node
                                }
                                return AnimatableSectionModel(model: section.section, items: items)
                        }
                    }
            }
            .bind(to: tableView.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)

    }
    
    public convenience init(tableView: UITableView, providers: [_AnimatableTableViewMultiNodeProvider]) {
        let sectionProviderTableViewBuilder = AnimatableTableViewSectionProvider(
            providers: providers,
            headerProvider: nil,
            footerProvider: nil
        )
        self.init(tableView: tableView, sectionProviders: [sectionProviderTableViewBuilder])
    }
    
}
