# Create Git tags plan

1. Add plain target/draft DTOs and service preparation/creation methods, plus pure
   validation for ref names, annotation identity, uniqueness and stale targets.
2. Extend the existing dialog with a New tag form and guarded events; retain
   drafts on errors, clear them on Back/success, and preserve branch behavior.
3. Add focused service/app unit coverage, run lint/render and affected native
   suites, deploy with source backups/readback verification.
4. Test lightweight and annotated creation, invalid/duplicate/stale refusals,
   Cancel and mobile layout on A4H25; remove temporary fixture refs and record
   findings. Do not commit or push without the user's instruction.
