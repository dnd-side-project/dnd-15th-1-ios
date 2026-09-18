import CoreNetwork
import Domain
import Foundation

public struct CoupleRepository: Sendable {
    private let coupleRemote: CoupleRemoteDataSource

    public init(coupleRemote: CoupleRemoteDataSource) {
        self.coupleRemote = coupleRemote
    }

    public func inviteCode() async throws -> InviteCode {
        do {
            return CoupleDTOMapper.toDomain(try await coupleRemote.connectionCode())
        } catch {
            throw CoupleErrorMapper.map(error)
        }
    }

    // 연결 코드의 공백 제거·대문자화는 서버도 하지만 클라이언트에서도 한다.
    // 정규화는 요청 body 를 만드는 CoupleDTOMapper.toRequest 한 곳에서만 일어난다.
    public func connect(inviteCode: String) async throws -> CoupleMember {
        do {
            return try CoupleDTOMapper.toPartner(try await coupleRemote.connect(connectionCode: inviteCode))
        } catch {
            throw CoupleErrorMapper.map(error)
        }
    }

    // 명세상 이 주소의 404 는 최초 프로필 설정을 마치지 않은 회원이라는 뜻이다.
    // 커플 연결은 닉네임 설정 뒤에 오므로 드물고, 화면은 연결 안 됨과 같게 다룬다.
    // CoupleErrorMapper 는 404 를 invalidInviteCode 로 보므로 그 매핑을 타면
    // 정상 흐름이 에러가 된다. 방어는 current() 에만 둔다.
    public func current() async throws -> CoupleStatus {
        do {
            return try CoupleDTOMapper.toStatus(try await coupleRemote.current())
        } catch NetworkError.notFound {
            return .notConnected
        } catch {
            throw CoupleErrorMapper.map(error)
        }
    }

    public func disconnect() async throws {
        do {
            try await coupleRemote.disconnect()
        } catch {
            throw CoupleErrorMapper.map(error)
        }
    }
}
