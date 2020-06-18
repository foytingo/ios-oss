import Foundation
import KsApi
import Prelude
import ReactiveSwift

public enum PledgeExpandableRewardsHeaderItem {
  case header(PledgeExpandableHeaderRewardCellData)
  case reward(PledgeExpandableHeaderRewardCellData)

  public var data: PledgeExpandableHeaderRewardCellData {
    switch self {
    case let .header(data): return data
    case let .reward(data): return data
    }
  }

  public var isHeader: Bool {
    switch self {
    case .header: return true
    case .reward: return false
    }
  }

  public var isReward: Bool {
    switch self {
    case .header: return false
    case .reward: return true
    }
  }
}

public typealias PledgeExpandableRewardsHeaderViewData = (
  rewards: [Reward],
  projectCountry: Project.Country,
  omitCurrencyCode: Bool
)

public protocol PledgeExpandableRewardsHeaderViewModelInputs {
  func configure(with data: PledgeExpandableRewardsHeaderViewData)
  func expandButtonTapped()
  func viewDidLoad()
}

public protocol PledgeExpandableRewardsHeaderViewModelOutputs {
  var loadRewardsIntoDataSource: Signal<[PledgeExpandableRewardsHeaderItem], Never> { get }
  var expandRewards: Signal<Bool, Never> { get }
}

public protocol PledgeExpandableRewardsHeaderViewModelType {
  var inputs: PledgeExpandableRewardsHeaderViewModelInputs { get }
  var outputs: PledgeExpandableRewardsHeaderViewModelOutputs { get }
}

public final class PledgeExpandableRewardsHeaderViewModel: PledgeExpandableRewardsHeaderViewModelType,
  PledgeExpandableRewardsHeaderViewModelInputs, PledgeExpandableRewardsHeaderViewModelOutputs {
  public init() {
    let data = Signal.combineLatest(
      self.configureWithRewardsProperty.signal.skipNil(),
      self.viewDidLoadProperty.signal
    )
    .map(first)

    let rewards = data.map(first)

    let latestRewardDeliveryDate = rewards.map { rewards in
      rewards
        .compactMap { $0.estimatedDeliveryOn }
        .reduce(0) { accum, value in max(accum, value) }
    }

    self.expandRewards = self.expandButtonTappedProperty.signal
      .scan(false) { current, _ in !current }

    let estimatedDeliveryString = latestRewardDeliveryDate.map { date -> String? in
      guard date > 0 else { return nil }

      let dateString = Format.date(
        secondsInUTC: date,
        template: DateFormatter.monthYear,
        timeZone: UTCTimeZone
      )

      return Strings.backing_info_estimated_delivery_date(delivery_date: dateString)
    }
    .skipNil()

    let total: Signal<Double, Never> = rewards.map { rewards in
      rewards.map { $0.minimum }.reduce(0, +)
    }

    self.loadRewardsIntoDataSource = Signal.zip(data, estimatedDeliveryString, total).map(items)
  }

  private let configureWithRewardsProperty = MutableProperty<PledgeExpandableRewardsHeaderViewData?>(nil)
  public func configure(with data: PledgeExpandableRewardsHeaderViewData) {
    self.configureWithRewardsProperty.value = data
  }

  private let expandButtonTappedProperty = MutableProperty(())
  public func expandButtonTapped() {
    self.expandButtonTappedProperty.value = ()
  }

  private let viewDidLoadProperty = MutableProperty(())
  public func viewDidLoad() {
    self.viewDidLoadProperty.value = ()
  }

  public let loadRewardsIntoDataSource: Signal<[PledgeExpandableRewardsHeaderItem], Never>
  public let expandRewards: Signal<Bool, Never>

  public var inputs: PledgeExpandableRewardsHeaderViewModelInputs { return self }
  public var outputs: PledgeExpandableRewardsHeaderViewModelOutputs { return self }
}

// MARK: - Functions

private func items(
  with data: PledgeExpandableRewardsHeaderViewData,
  estimatedDeliveryString: String,
  total: Double
) -> [PledgeExpandableRewardsHeaderItem] {
  guard let totalAmountAttributedText = attributedHeaderCurrency(
    with: data.projectCountry, amount: total, omitUSCurrencyCode: data.omitCurrencyCode
  ) else { return [] }

  let headerItem = PledgeExpandableRewardsHeaderItem.header((
    text: estimatedDeliveryString,
    amount: totalAmountAttributedText
  ))

  let rewardItems = data.rewards.compactMap { reward -> PledgeExpandableRewardsHeaderItem? in
    guard let title = reward.title else { return nil }

    let amountAttributedText = attributedRewardCurrency(
      with: data.projectCountry, amount: reward.minimum, omitUSCurrencyCode: data.omitCurrencyCode
    )

    return PledgeExpandableRewardsHeaderItem.reward((
      text: title,
      amount: amountAttributedText
    ))
  }

  return [headerItem] + rewardItems
}

private func attributedHeaderCurrency(
  with projectCountry: Project.Country,
  amount: Double,
  omitUSCurrencyCode: Bool
) -> NSAttributedString? {
  let defaultAttributes = checkoutCurrencyDefaultAttributes()
    .withAllValuesFrom([.foregroundColor: UIColor.ksr_dark_grey_500])
  let superscriptAttributes = checkoutCurrencySuperscriptAttributes()
  guard
    let attributedCurrency = Format.attributedCurrency(
      amount,
      country: projectCountry,
      omitCurrencyCode: omitUSCurrencyCode,
      defaultAttributes: defaultAttributes,
      superscriptAttributes: superscriptAttributes,
      maximumFractionDigits: 0,
      minimumFractionDigits: 0
    ) else { return nil }

  return attributedCurrency
}

private func attributedRewardCurrency(
  with projectCountry: Project.Country,
  amount: Double,
  omitUSCurrencyCode: Bool
) -> NSAttributedString {
  let currencyString = Format.currency(
    amount,
    country: projectCountry,
    omitCurrencyCode: omitUSCurrencyCode,
    maximumFractionDigits: 0,
    minimumFractionDigits: 0
  )

  return NSAttributedString(
    string: currencyString,
    attributes: [
      .foregroundColor: UIColor.ksr_dark_grey_500,
      .font: UIFont.ksr_subhead().bolded
    ]
  )
}
