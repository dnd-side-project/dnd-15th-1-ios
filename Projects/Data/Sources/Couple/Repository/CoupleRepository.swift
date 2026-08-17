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
    public func connect(inviteCode: String) async throws -> Couple {
        do {
            let status = try await coupleRemote.connect(connectionCode: inviteCode)
            guard let couple = CoupleDTOMapper.toDomain(status) else {
                throw CoupleError.unknown
            }
            return couple
        } catch {
            throw CoupleErrorMapper.map(error)
        }
    }

    // 명세상 미연결은 200 + `connected: false` 라서 매퍼가 nil 로 처리한다.
    // 다만 서버가 커플 없음을 404 로 답하는 경우도 있어 여기서만 nil 로 방어한다.
    // CoupleErrorMapper 는 404 를 invalidInviteCode 로 보므로 그 매핑을 타면
    // 커플이 없는 정상 상태가 에러가 된다. 방어는 current() 에만 둔다.
    public func current() async throws -> CoupleStatus? {
        do {
            return try CoupleDTOMapper.toStatus(try await coupleRemote.current())
        } catch NetworkError.notFound {
            return nil
        } catch let error as CoupleError {
            // 매퍼가 올린 불완전 응답 에러는 그대로 전달
            throw error
        } catch {
            throw CoupleErrorMapper.map(error)
        }
    }
}
