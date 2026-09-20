import Foundation
import ThirdParty

public extension NoticeClient {
    static let mock = NoticeClient(
        notices: { _ in
            NoticePage(items: Notice.mocks, hasNext: false)
        }
    )
}

public extension Notice {
    static let mocks: [Notice] = [
        Notice(
            id: "1",
            title: "둘픽 업데이트 안내",
            content: "새로운 기능이 추가되었습니다. 앱을 최신 버전으로 올려 주세요.",
            createdAt: Date(timeIntervalSince1970: 1_788_742_800)
        ),
        Notice(
            id: "2",
            title: "서비스 점검 안내",
            content: "9월 3일 새벽 2시부터 4시까지 점검이 있습니다. 이 시간에는 접속이 되지 않습니다.",
            createdAt: Date(timeIntervalSince1970: 1_788_397_200)
        ),
        Notice(
            id: "3",
            title: "개인정보 처리방침 변경 안내",
            content: "개인정보 처리방침이 바뀌었습니다. 자세한 내용은 설정에서 확인하실 수 있습니다.",
            createdAt: Date(timeIntervalSince1970: 1_787_792_400)
        ),
    ]
}
