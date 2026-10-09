# Tag review fix plan

1. Create fix/tag-review-findings from main and inspect transport APIs.
2. Share the pure fixed-commit/switched-origin guard across tag operations.
3. Verify object types with shallow fetches; keep deletion on raw refs.
4. Add service and status regression tests and document lookup costs.
5. Run npm run check, review the diff, and report without SAP access.
