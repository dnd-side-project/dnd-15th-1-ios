//
//  HomeDTOMapper.swift
//  Dulpick
//
//  Created by 이인호 on 8/21/26.
//

import Domain
import Foundation

enum HomeDTOMapper {
    static func toDomain(_ dto: HomeSummaryResponseDTO) -> HomeSummary {
        HomeSummary(
            connected: dto.connected,
            myNickname: dto.myNickname ?? "",
            partnerNickname: dto.connected ? dto.partnerNickname : nil
        )
    }
}
