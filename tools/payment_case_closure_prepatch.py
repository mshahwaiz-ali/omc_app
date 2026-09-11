from pathlib import Path

path = Path(
    "omc_app/lib/features/internal_workspace/presentation/"
    "internal_operations_center_screen.dart"
)
text = path.read_text(encoding="utf-8")
old = '''    case PaymentStatus.receiptSubmitted:
      return const _PaymentReviewVisual(
        color: AppTheme.info,
        background: AppTheme.infoSoft,
        icon: Icons.upload_file_outlined,
        message: 'Receipt submitted; verification is still pending.',
      );
    case PaymentStatus.underReview:
      return const _PaymentReviewVisual(
        color: AppTheme.info,
        background: AppTheme.infoSoft,
        icon: Icons.fact_check_outlined,
        message: 'Receipt is currently under review.',
      );
'''
new = '''    case PaymentStatus.receiptSubmitted:
    case PaymentStatus.underReview:
      return const _PaymentReviewVisual(
        color: AppTheme.info,
        background: AppTheme.infoSoft,
        icon: Icons.manage_search_rounded,
        message: 'Payment proof is awaiting review.',
      );
'''
count = text.count(old)
if count != 1:
    raise SystemExit(f"expected one payment visual block, found {count}")
path.write_text(text.replace(old, new, 1), encoding="utf-8")
print("Payment visual normalized for exact closure patch.")
