# UI Refinements Backup - December 15, 2025

## Summary
This backup documents UI refinements made to action buttons and checkboxes across leads and clients tables.

## Changes Made

### 1. Row Action Buttons (28px)
Updated button sizes to h-7 w-7 (28px) with 14px icons across:

**Files Modified:**
- `src/components/clients/ClientRowActions.tsx`
- `src/components/leads/LeadRowActions.tsx`
- `src/components/leads/LeadsTableContent.tsx`

**Button Styling:**
```tsx
<Button variant="secondary" className="h-7 w-7 p-0 [&_svg]:size-3.5">
```

### 2. Checkbox Component Fix
Fixed checkbox centering issue by reducing check icon size.

**File Modified:**
- `src/components/ui/checkbox.tsx`

**Change:**
- Check icon reduced from `h-4 w-4` to `h-3 w-3` for proper centering within the checkbox

### 3. Table Checkbox Standardization
Removed custom checkbox sizing to use consistent default size (16px).

**Files Modified:**
- `src/components/leads/LeadsTableContent.tsx` - Removed `className="h-3.5 w-3.5"`
- `src/components/clients/ClientsTableView.tsx` - Removed `className="h-3.5 w-3.5"`

## Current State

### Action Button Sizes
- Button: 28px x 28px (h-7 w-7)
- Icon: 14px (size-3.5)
- Gap between buttons: 2px (gap-0.5)

### Checkbox Sizes
- Checkbox: 16px x 16px (h-4 w-4) - default
- Check icon: 12px x 12px (h-3 w-3)

## Affected Components
1. ClientRowActions - Plus dropdown, Phone, Mail buttons
2. LeadRowActions - Plus dropdown, Phone, Mail, Convert buttons
3. LeadsTableContent - Inline action buttons in table rows
4. ClientsTableView - Row selection checkboxes
5. Checkbox UI component - Global check icon sizing
