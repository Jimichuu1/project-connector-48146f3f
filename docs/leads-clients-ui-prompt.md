# Leads & Clients UI Design Specification

## Overview

This document provides a complete UI specification for the Leads and Clients pages, including layout structure, component styling, interactions, responsive behavior, and visual hierarchy.

---

## Design System Reference

### Color Tokens (from index.css)
```css
/* Use semantic tokens - NEVER hardcode colors */
--background: /* page background */
--foreground: /* primary text */
--card: /* card backgrounds */
--card-foreground: /* card text */
--primary: /* brand color, buttons, badges */
--primary-foreground: /* text on primary */
--secondary: /* secondary elements */
--muted: /* muted backgrounds */
--muted-foreground: /* secondary text */
--accent: /* hover states, highlights */
--border: /* borders, dividers */
--destructive: /* delete actions, errors */
```

### Typography
- **Page Title**: `text-2xl font-bold tracking-tight`
- **Page Description**: `text-muted-foreground text-sm`
- **Card Title**: `text-sm font-medium`
- **Card Value**: `text-2xl font-bold`
- **Table Header**: `font-medium text-muted-foreground`
- **Table Cell**: `text-sm`
- **Badge**: `text-xs font-semibold`

---

## Page Layout Structure

### Leads Page Layout

```
┌─────────────────────────────────────────────────────────────────┐
│ HEADER                                                          │
│ ┌───────────────────────────────────────────────────────────┐   │
│ │ [Leads] [Badge: 1,234]                                    │   │
│ │ Manage and track your sales leads                         │   │
│ └───────────────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────────────┤
│ TOOLBAR                                                         │
│ ┌───────────────────────────────────────────────────────────┐   │
│ │ [Table][Board][Groups]  |  [Search...]  [Import][Export][+Add]│
│ └───────────────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────────────┤
│ FILTERS                                                         │
│ ┌───────────────────────────────────────────────────────────┐   │
│ │ [Status ▼] [Country ▼] [Agent ▼] [Date ▼] [Group ▼] [□ Unassigned]│
│ └───────────────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────────────┤
│ CONTENT AREA (Table View)                                       │
│ ┌───────────────────────────────────────────────────────────┐   │
│ │ [□] Name        Email         Phone    Status   Created  ⋮ │   │
│ │ ─────────────────────────────────────────────────────────── │   │
│ │ [□] John Doe    j@email.com   +1...    [NEW▼]   Dec 29   ⋮ │   │
│ │ [□] Jane Smith  j@email.com   +1...    [HOT▼]   Dec 28   ⋮ │   │
│ │ [□] Bob Wilson  b@email.com   +1...    [WARM▼]  Dec 27   ⋮ │   │
│ └───────────────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────────────┤
│ PAGINATION                                                      │
│ ┌───────────────────────────────────────────────────────────┐   │
│ │ Showing 1-25 of 1,234 leads    [◀] 1 2 3 ... 50 [▶]  [25▼]│   │
│ └───────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ FLOATING BAR (when items selected)                              │
│ ┌───────────────────────────────────────────────────────────┐   │
│ │ 5 selected  [Status▼] [Assign] [Shuffle] [Group▼] [Delete]│   │
│ └───────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

### Clients Page Layout

```
┌─────────────────────────────────────────────────────────────────┐
│ HEADER                                                          │
│ ┌───────────────────────────────────────────────────────────┐   │
│ │ [Clients] [Badge: 567]                                    │   │
│ │ Track and manage your active clients                      │   │
│ └───────────────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────────────┤
│ STATS CARDS                                                     │
│ ┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐  │
│ │ Total Clients    │ │ Total Balance    │ │ Total Initial    │  │
│ │ [UserPlus icon]  │ │ [Dollar icon]    │ │ [TrendUp icon]   │  │
│ │ 567              │ │ $1,234,567       │ │ $987,654         │  │
│ └──────────────────┘ └──────────────────┘ └──────────────────┘  │
├─────────────────────────────────────────────────────────────────┤
│ TOOLBAR                                                         │
│ ┌───────────────────────────────────────────────────────────┐   │
│ │ [Table][Board]  |  [Search...]  [Import][Export][+Add Client] │
│ └───────────────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────────────┤
│ FILTERS                                                         │
│ ┌───────────────────────────────────────────────────────────┐   │
│ │ [Status ▼] [Country ▼] [Agent ▼] [Group ▼] [Has Deposit ▼]│   │
│ └───────────────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────────────┤
│ CONTENT AREA (Table View)                                       │
│ ┌───────────────────────────────────────────────────────────┐   │
│ │ [□] Name      Email      Status   Balance   Initial    ⋮  │   │
│ │ ─────────────────────────────────────────────────────────── │   │
│ │▌[□] John Doe  j@e.com   [ACTIVE▼] $12,345   $10,000    ⋮  │   │ ← green left border = has deposit
│ │ [□] Jane S.   j@e.com   [NEW▼]    $0        $0         ⋮  │   │
│ └───────────────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────────────┤
│ PAGINATION                                                      │
│ ┌───────────────────────────────────────────────────────────┐   │
│ │ Showing 1-25 of 567 clients    [◀] 1 2 3 ... 23 [▶]  [25▼]│   │
│ └───────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

---

## Component Specifications

### 1. Page Header

```tsx
<div>
  <div className="flex items-center gap-2">
    <h1 className="text-2xl font-bold tracking-tight">Leads</h1>
    <Badge variant="default" className="text-sm h-6 px-2">
      {totalCount.toLocaleString()}
    </Badge>
  </div>
  <p className="text-muted-foreground text-sm mt-1">
    Manage and track your sales leads
  </p>
</div>
```

**Styling:**
- Title: Bold, 2xl size
- Badge: Primary background, shows total count formatted with locale
- Description: Muted color, small text

---

### 2. Stats Cards (Clients Only)

```tsx
<div className="grid gap-4 md:grid-cols-3">
  <Card className="bg-primary text-primary-foreground">
    <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
      <CardTitle className="text-sm font-medium">Total Clients</CardTitle>
      <UserPlus className="h-4 w-4" />
    </CardHeader>
    <CardContent>
      <div className="text-2xl font-bold">{stats.totalClients.toLocaleString()}</div>
    </CardContent>
  </Card>
  {/* Repeat for Balance and Initial Amount */}
</div>
```

**Styling:**
- Background: Primary color
- Text: Primary foreground (contrast)
- Icon: 4x4 size, positioned top-right
- Value: 2xl bold
- Grid: 3 columns on desktop, 1 on mobile

---

### 3. Toolbar

```tsx
<div className="flex items-center justify-between py-4 border-b border-border">
  {/* Left: View Toggle */}
  <div className="flex items-center gap-2">
    <ToggleGroup type="single" value={viewMode} onValueChange={setViewMode}>
      <ToggleGroupItem value="table" size="sm" className="gap-2">
        <TableIcon className="h-4 w-4" />
        Table
      </ToggleGroupItem>
      <ToggleGroupItem value="board" size="sm" className="gap-2">
        <KanbanSquare className="h-4 w-4" />
        Board
      </ToggleGroupItem>
      {/* Groups toggle for Leads only */}
    </ToggleGroup>
  </div>

  {/* Right: Search + Actions */}
  <div className="flex items-center gap-2">
    <SearchFilter value={search} onChange={setSearch} placeholder="Search..." />
    <Button variant="ghost" size="sm" onClick={onImport}>
      <Upload className="h-4 w-4 mr-1" />
      Import
    </Button>
    <Button variant="ghost" size="sm" onClick={onExport}>
      <Download className="h-4 w-4 mr-1" />
      Export
    </Button>
    <Button size="sm" onClick={onAdd} className="gap-2">
      Add Lead
      <UserPlus className="h-4 w-4" />
    </Button>
  </div>
</div>
```

**Styling:**
- Border bottom for separation
- Toggle group with icon + text
- Ghost variant for secondary actions
- Primary variant for main CTA

---

### 4. Filter Bar

```tsx
<div className="flex flex-wrap items-center gap-2 py-3">
  <MultiSelectFilter
    label="Status"
    options={statusOptions}
    value={selectedStatuses}
    onChange={setSelectedStatuses}
  />
  <MultiSelectFilter
    label="Country"
    options={countryOptions}
    value={filterValues.country}
    onChange={(val) => setFilterValues({...filterValues, country: val})}
  />
  <MultiSelectFilter
    label="Assigned To"
    options={agentOptions}
    value={filterValues.assignedTo}
    onChange={(val) => setFilterValues({...filterValues, assignedTo: val})}
  />
  {/* Additional filters */}
  
  {/* Unassigned toggle (Leads only) */}
  <div className="flex items-center gap-2 ml-2">
    <Checkbox 
      checked={filterValues.unassigned} 
      onCheckedChange={(checked) => setFilterValues({...filterValues, unassigned: checked})}
    />
    <Label className="text-sm text-muted-foreground">Unassigned only</Label>
  </div>
</div>
```

**Styling:**
- Flex wrap for responsive
- Gap-2 between filters
- Consistent filter button styling

---

### 5. Data Table

```tsx
<Table>
  <TableHeader>
    <TableRow className="hover:bg-transparent">
      <TableHead className="w-12">
        <Checkbox checked={allSelected} onCheckedChange={handleSelectAll} />
      </TableHead>
      <SortableTableHead 
        label="Name" 
        sortKey="name" 
        currentSort={sort} 
        onSort={handleSort} 
      />
      <TableHead>Email</TableHead>
      <TableHead>Phone</TableHead>
      <TableHead>Status</TableHead>
      <TableHead>Created</TableHead>
      <TableHead className="w-10"></TableHead> {/* Actions */}
    </TableRow>
  </TableHeader>
  <TableBody>
    {leads.map((lead) => (
      <TableRow 
        key={lead.id}
        className="cursor-pointer hover:bg-muted/50"
        onClick={() => navigate(`/leads/${lead.id}`)}
      >
        <TableCell onClick={(e) => e.stopPropagation()}>
          <Checkbox checked={selectedLeads.includes(lead.id)} />
        </TableCell>
        <TableCell>
          <div>
            <p className="font-medium">{lead.name}</p>
            {lead.company && (
              <p className="text-xs text-muted-foreground">{lead.company}</p>
            )}
          </div>
        </TableCell>
        <TableCell>
          {shouldShowEmail ? lead.email : maskEmail(lead.email)}
        </TableCell>
        <TableCell>
          {shouldShowPhone ? lead.phone : maskPhone(lead.phone)}
        </TableCell>
        <TableCell onClick={(e) => e.stopPropagation()}>
          <LeadStatusDropdown status={lead.status} onStatusChange={handleStatusChange} />
        </TableCell>
        <TableCell className="text-muted-foreground">
          {formatDate(lead.created_at)}
        </TableCell>
        <TableCell onClick={(e) => e.stopPropagation()}>
          <LeadRowActions lead={lead} {...actionProps} />
        </TableCell>
      </TableRow>
    ))}
  </TableBody>
</Table>
```

**Client Table - Deposit Highlighting:**
```tsx
<TableRow
  className={cn(
    "cursor-pointer hover:bg-muted/50",
    hasDeposit && "border-l-4 border-l-green-500 bg-green-500/5"
  )}
>
```

---

### 6. Status Dropdown

```tsx
<Popover open={open} onOpenChange={setOpen}>
  <PopoverTrigger asChild>
    <Button
      size="sm"
      variant="ghost"
      className="h-6 px-2 gap-1 rounded-full text-xs font-semibold"
      style={{ backgroundColor: statusColor, color: "#000" }}
    >
      {status.replace(/_/g, " ")}
      <ChevronDown className="h-3 w-3" />
    </Button>
  </PopoverTrigger>
  <PopoverContent className="w-48 p-2 bg-popover" align="start">
    <div className="space-y-1">
      {statuses.map((s) => (
        <Button
          key={s.name}
          size="sm"
          variant="ghost"
          className={cn(
            "w-full justify-start text-sm gap-2",
            status === s.name && "bg-accent"
          )}
          onClick={() => onStatusChange(s.name)}
        >
          <span 
            className="w-3 h-3 rounded-full" 
            style={{ backgroundColor: s.color }}
          />
          {s.name.replace(/_/g, " ")}
        </Button>
      ))}
    </div>
  </PopoverContent>
</Popover>
```

**Styling:**
- Pill-shaped badge (rounded-full)
- Color from database
- Black text for contrast
- Dropdown with color indicators

---

### 7. Row Actions Menu

```tsx
<DropdownMenu>
  <DropdownMenuTrigger asChild>
    <Button variant="ghost" size="icon" className="h-8 w-8">
      <MoreHorizontal className="h-4 w-4" />
    </Button>
  </DropdownMenuTrigger>
  <DropdownMenuContent align="end" className="w-48 bg-popover z-50">
    <DropdownMenuItem onClick={() => navigate(`/leads/${lead.id}`)}>
      <Eye className="mr-2 h-4 w-4" />
      View Details
    </DropdownMenuItem>
    {cccEnabled && (
      <DropdownMenuItem onClick={() => onCall(lead)}>
        <Phone className="mr-2 h-4 w-4" />
        Call
      </DropdownMenuItem>
    )}
    {emailEnabled && (
      <DropdownMenuItem onClick={() => onEmail(lead)}>
        <Mail className="mr-2 h-4 w-4" />
        Send Email
      </DropdownMenuItem>
    )}
    <DropdownMenuItem onClick={() => onAddBank(lead)}>
      <Building2 className="mr-2 h-4 w-4" />
      Add Bank
    </DropdownMenuItem>
    <DropdownMenuItem onClick={() => onAddNote(lead)}>
      <StickyNote className="mr-2 h-4 w-4" />
      Add Note
    </DropdownMenuItem>
    <DropdownMenuSeparator />
    {canConvert && (
      <DropdownMenuItem onClick={() => onConvert(lead)}>
        <UserCheck className="mr-2 h-4 w-4" />
        Convert to Client
      </DropdownMenuItem>
    )}
  </DropdownMenuContent>
</DropdownMenu>
```

**Styling:**
- Ghost icon button trigger
- Solid background (bg-popover)
- High z-index (z-50)
- Icons with mr-2 spacing

---

### 8. Floating Selection Bar

```tsx
<div className="fixed bottom-6 left-1/2 -translate-x-1/2 z-50">
  <div className="flex items-center gap-3 bg-background border border-border rounded-lg shadow-lg px-4 py-3">
    <span className="text-sm font-medium">
      {selectedLeads.length} selected
    </span>
    <div className="h-4 w-px bg-border" />
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button variant="ghost" size="sm">
          <Tag className="h-4 w-4 mr-1" />
          Status
          <ChevronDown className="h-3 w-3 ml-1" />
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent className="bg-popover">
        {statuses.map((s) => (
          <DropdownMenuItem key={s.name} onClick={() => handleBulkStatus(s.name)}>
            {s.name}
          </DropdownMenuItem>
        ))}
      </DropdownMenuContent>
    </DropdownMenu>
    <Button variant="ghost" size="sm" onClick={onAssign}>
      <UserPlus className="h-4 w-4 mr-1" />
      Assign
    </Button>
    <Button variant="ghost" size="sm" onClick={onShuffle}>
      <Shuffle className="h-4 w-4 mr-1" />
      Shuffle
    </Button>
    <Button variant="ghost" size="sm" onClick={onAddToGroup}>
      <FolderPlus className="h-4 w-4 mr-1" />
      Add to Group
    </Button>
    {canDelete && (
      <Button variant="ghost" size="sm" className="text-destructive" onClick={onDelete}>
        <Trash2 className="h-4 w-4 mr-1" />
        Delete
      </Button>
    )}
    <div className="h-4 w-px bg-border" />
    <Button variant="ghost" size="sm" onClick={onClear}>
      <X className="h-4 w-4" />
    </Button>
  </div>
</div>
```

**Styling:**
- Fixed position at bottom center
- Elevated with shadow
- Solid background
- Dividers between action groups
- Destructive color for delete

---

### 9. Kanban Board View

```tsx
<div className="flex gap-4 overflow-x-auto pb-4">
  {statuses.map((status) => (
    <div 
      key={status.name}
      className="flex-shrink-0 w-72 bg-muted/30 rounded-lg p-3"
    >
      {/* Column Header */}
      <div className="flex items-center justify-between mb-3">
        <div className="flex items-center gap-2">
          <span 
            className="w-3 h-3 rounded-full"
            style={{ backgroundColor: status.color }}
          />
          <span className="font-medium text-sm">{status.name}</span>
          <Badge variant="secondary" className="text-xs">
            {getLeadsByStatus(status.name).length}
          </Badge>
        </div>
      </div>
      
      {/* Column Content */}
      <div className="space-y-2">
        {getLeadsByStatus(status.name).map((lead) => (
          <Card 
            key={lead.id}
            className="p-3 cursor-pointer hover:shadow-md transition-shadow"
            onClick={() => navigate(`/leads/${lead.id}`)}
          >
            <p className="font-medium text-sm">{lead.name}</p>
            {lead.company && (
              <p className="text-xs text-muted-foreground">{lead.company}</p>
            )}
            <div className="flex items-center gap-2 mt-2 text-xs text-muted-foreground">
              {lead.country && <span>{getFlag(lead.country)}</span>}
              {lead.assigned_to && <UserDisplay userId={lead.assigned_to} />}
            </div>
          </Card>
        ))}
      </div>
    </div>
  ))}
</div>
```

**Styling:**
- Horizontal scroll with overflow-x-auto
- Fixed column width (w-72)
- Subtle background (muted/30)
- Card hover effect
- Color indicators for status

---

### 10. Groups View (Leads Only)

```tsx
<div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
  {groups.map((group) => (
    <Card key={group.id} className="relative">
      <CardHeader className="pb-2">
        <div className="flex items-center justify-between">
          <CardTitle className="text-lg">{group.name}</CardTitle>
          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <Button variant="ghost" size="icon" className="h-8 w-8">
                <MoreVertical className="h-4 w-4" />
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end" className="bg-popover">
              <DropdownMenuItem onClick={() => onShuffleGroup(group.id, group.name)}>
                <Shuffle className="mr-2 h-4 w-4" />
                Shuffle Unassigned
              </DropdownMenuItem>
              <DropdownMenuItem onClick={() => onViewGroup(group.id)}>
                <Eye className="mr-2 h-4 w-4" />
                View Leads
              </DropdownMenuItem>
              <DropdownMenuSeparator />
              <DropdownMenuItem 
                className="text-destructive"
                onClick={() => onDeleteGroup(group.id)}
              >
                <Trash2 className="mr-2 h-4 w-4" />
                Delete Group
              </DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>
        </div>
        {group.description && (
          <p className="text-sm text-muted-foreground">{group.description}</p>
        )}
      </CardHeader>
      <CardContent>
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-4">
            <div className="text-center">
              <p className="text-2xl font-bold">{group.memberCount}</p>
              <p className="text-xs text-muted-foreground">Total</p>
            </div>
            <div className="text-center">
              <p className="text-2xl font-bold text-orange-500">{group.unassignedCount}</p>
              <p className="text-xs text-muted-foreground">Unassigned</p>
            </div>
          </div>
          <Button 
            variant="outline" 
            size="sm"
            onClick={() => onViewGroup(group.id)}
          >
            View
          </Button>
        </div>
      </CardContent>
    </Card>
  ))}
</div>
```

**Styling:**
- Grid layout (responsive columns)
- Card with header and content sections
- Stats display with large numbers
- Orange highlight for unassigned count

---

### 11. Pagination Controls

```tsx
<div className="flex items-center justify-between px-4 py-3 border-t border-border">
  <div className="text-sm text-muted-foreground">
    Showing {startIndex}-{endIndex} of {totalCount.toLocaleString()} {itemLabel}
  </div>
  
  <div className="flex items-center gap-4">
    <Pagination>
      <PaginationContent>
        <PaginationItem>
          <PaginationPrevious 
            onClick={() => onPageChange(currentPage - 1)}
            disabled={currentPage === 1}
          />
        </PaginationItem>
        {/* Page numbers */}
        <PaginationItem>
          <PaginationNext 
            onClick={() => onPageChange(currentPage + 1)}
            disabled={currentPage === totalPages}
          />
        </PaginationItem>
      </PaginationContent>
    </Pagination>
    
    <Select value={pageSize.toString()} onValueChange={(v) => onPageSizeChange(Number(v))}>
      <SelectTrigger className="w-20">
        <SelectValue />
      </SelectTrigger>
      <SelectContent className="bg-popover">
        {pageSizeOptions.map((size) => (
          <SelectItem key={size} value={size.toString()}>{size}</SelectItem>
        ))}
      </SelectContent>
    </Select>
  </div>
</div>
```

**Styling:**
- Border top for separation
- Muted text for info
- Compact select for page size

---

## Dialog Specifications

### Create/Edit Lead Dialog

```tsx
<Dialog open={open} onOpenChange={onOpenChange}>
  <DialogContent className="sm:max-w-[500px]">
    <DialogHeader>
      <DialogTitle>Add New Lead</DialogTitle>
      <DialogDescription>
        Enter the lead details below.
      </DialogDescription>
    </DialogHeader>
    
    <form onSubmit={handleSubmit}>
      <div className="grid gap-4 py-4">
        <div className="grid grid-cols-4 items-center gap-4">
          <Label htmlFor="name" className="text-right">Name *</Label>
          <Input id="name" className="col-span-3" {...register("name")} />
        </div>
        <div className="grid grid-cols-4 items-center gap-4">
          <Label htmlFor="email" className="text-right">Email</Label>
          <Input id="email" type="email" className="col-span-3" {...register("email")} />
        </div>
        <div className="grid grid-cols-4 items-center gap-4">
          <Label htmlFor="phone" className="text-right">Phone</Label>
          <Input id="phone" className="col-span-3" {...register("phone")} />
        </div>
        <div className="grid grid-cols-4 items-center gap-4">
          <Label htmlFor="country" className="text-right">Country</Label>
          <Select {...register("country")}>
            <SelectTrigger className="col-span-3">
              <SelectValue placeholder="Select country" />
            </SelectTrigger>
            <SelectContent className="bg-popover max-h-60">
              {countries.map((c) => (
                <SelectItem key={c.code} value={c.code}>
                  {c.flag} {c.name}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>
        <div className="grid grid-cols-4 items-center gap-4">
          <Label htmlFor="source" className="text-right">Source</Label>
          <Select {...register("source")}>
            <SelectTrigger className="col-span-3">
              <SelectValue placeholder="Select source" />
            </SelectTrigger>
            <SelectContent className="bg-popover">
              {sources.map((s) => (
                <SelectItem key={s} value={s}>{s.replace(/_/g, " ")}</SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>
      </div>
      
      <DialogFooter>
        <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
          Cancel
        </Button>
        <Button type="submit" disabled={isLoading}>
          {isLoading && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
          Create Lead
        </Button>
      </DialogFooter>
    </form>
  </DialogContent>
</Dialog>
```

### Import Dialog

```tsx
<Dialog open={open} onOpenChange={onOpenChange}>
  <DialogContent className="sm:max-w-[600px]">
    <DialogHeader>
      <DialogTitle>Import Leads from CSV</DialogTitle>
      <DialogDescription>
        Upload a CSV file to import multiple leads at once.
      </DialogDescription>
    </DialogHeader>
    
    <div className="py-4">
      {/* Drop Zone */}
      <div 
        {...getRootProps()}
        className={cn(
          "border-2 border-dashed rounded-lg p-8 text-center cursor-pointer transition-colors",
          isDragActive ? "border-primary bg-primary/5" : "border-border hover:border-primary/50"
        )}
      >
        <input {...getInputProps()} />
        <Upload className="h-10 w-10 mx-auto mb-4 text-muted-foreground" />
        <p className="text-sm text-muted-foreground">
          Drag & drop a CSV file here, or click to select
        </p>
      </div>
      
      {/* Preview Table */}
      {previewData.length > 0 && (
        <div className="mt-4 max-h-60 overflow-auto border rounded-lg">
          <Table>
            <TableHeader>
              <TableRow>
                {columns.map((col) => (
                  <TableHead key={col}>{col}</TableHead>
                ))}
              </TableRow>
            </TableHeader>
            <TableBody>
              {previewData.slice(0, 5).map((row, i) => (
                <TableRow key={i}>
                  {columns.map((col) => (
                    <TableCell key={col}>{row[col]}</TableCell>
                  ))}
                </TableRow>
              ))}
            </TableBody>
          </Table>
          {previewData.length > 5 && (
            <p className="text-sm text-muted-foreground p-2 text-center">
              ... and {previewData.length - 5} more rows
            </p>
          )}
        </div>
      )}
      
      {/* Download Template Link */}
      <Button variant="link" className="mt-4 p-0" onClick={onDownloadTemplate}>
        <Download className="h-4 w-4 mr-1" />
        Download CSV template
      </Button>
    </div>
    
    <DialogFooter>
      <Button variant="outline" onClick={() => onOpenChange(false)}>Cancel</Button>
      <Button onClick={handleImport} disabled={!file || isLoading}>
        {isLoading && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
        Import {previewData.length} Leads
      </Button>
    </DialogFooter>
  </DialogContent>
</Dialog>
```

### Shuffle Dialog

```tsx
<Dialog open={open} onOpenChange={onOpenChange}>
  <DialogContent className="sm:max-w-[500px]">
    <DialogHeader>
      <DialogTitle>Shuffle Lead Assignment</DialogTitle>
      <DialogDescription>
        Randomly distribute {leadIds.length} leads among selected agents.
      </DialogDescription>
    </DialogHeader>
    
    <div className="py-4 space-y-4">
      {/* Agent Selection */}
      <div>
        <Label className="mb-2 block">Select agents to include:</Label>
        <div className="space-y-2 max-h-48 overflow-auto border rounded-lg p-3">
          {agents.map((agent) => (
            <div key={agent.id} className="flex items-center gap-2">
              <Checkbox 
                checked={selectedAgents.includes(agent.id)}
                onCheckedChange={(checked) => toggleAgent(agent.id, checked)}
              />
              <Label className="font-normal">{agent.full_name}</Label>
            </div>
          ))}
        </div>
      </div>
      
      {/* Distribution Preview */}
      {selectedAgents.length > 0 && (
        <div className="bg-muted/50 rounded-lg p-3">
          <p className="text-sm text-muted-foreground mb-2">Distribution preview:</p>
          <p className="text-sm">
            Each agent will receive approximately{" "}
            <span className="font-bold">
              {Math.floor(leadIds.length / selectedAgents.length)}
            </span>{" "}
            leads
          </p>
        </div>
      )}
    </div>
    
    <DialogFooter>
      <Button variant="outline" onClick={() => onOpenChange(false)}>Cancel</Button>
      <Button 
        onClick={handleShuffle} 
        disabled={selectedAgents.length === 0 || isLoading}
      >
        {isLoading && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
        Shuffle {leadIds.length} Leads
      </Button>
    </DialogFooter>
  </DialogContent>
</Dialog>
```

---

## Responsive Behavior

### Breakpoints
- **Mobile (< 768px)**: Single column, stacked layout
- **Tablet (768px - 1024px)**: 2 columns, compact spacing
- **Desktop (> 1024px)**: Full layout, all features

### Mobile Adaptations

1. **Table View**: Horizontal scroll with essential columns only
2. **Filters**: Collapsible filter drawer
3. **Stats Cards**: Single column stack
4. **Floating Bar**: Full width at bottom
5. **Board View**: Single column with horizontal scroll

```tsx
// Mobile Filter Drawer
<Sheet>
  <SheetTrigger asChild>
    <Button variant="outline" size="sm" className="md:hidden">
      <Filter className="h-4 w-4 mr-1" />
      Filters
    </Button>
  </SheetTrigger>
  <SheetContent side="bottom" className="h-[60vh]">
    <SheetHeader>
      <SheetTitle>Filters</SheetTitle>
    </SheetHeader>
    <div className="space-y-4 py-4">
      {/* All filters stacked vertically */}
    </div>
  </SheetContent>
</Sheet>
```

---

## Animation & Transitions

### Page Load
```tsx
<div className="animate-fade-in">
  {/* Content */}
</div>
```

### View Mode Transition
```tsx
{viewMode === "board" && (
  <div className="animate-fade-in p-4">
    <LeadsBoardView />
  </div>
)}
```

### Floating Bar Entrance
```css
@keyframes slide-up {
  from {
    opacity: 0;
    transform: translate(-50%, 20px);
  }
  to {
    opacity: 1;
    transform: translate(-50%, 0);
  }
}

.floating-bar {
  animation: slide-up 0.2s ease-out;
}
```

### Row Hover
```tsx
<TableRow className="transition-colors hover:bg-muted/50">
```

### Card Hover
```tsx
<Card className="transition-shadow hover:shadow-md">
```

---

## Loading States

### Table Skeleton
```tsx
{isLoading && (
  <>
    {[...Array(5)].map((_, i) => (
      <TableRow key={i}>
        <TableCell><Skeleton className="h-4 w-4" /></TableCell>
        <TableCell><Skeleton className="h-4 w-32" /></TableCell>
        <TableCell><Skeleton className="h-4 w-40" /></TableCell>
        <TableCell><Skeleton className="h-4 w-24" /></TableCell>
        <TableCell><Skeleton className="h-6 w-16 rounded-full" /></TableCell>
        <TableCell><Skeleton className="h-4 w-20" /></TableCell>
        <TableCell><Skeleton className="h-8 w-8 rounded" /></TableCell>
      </TableRow>
    ))}
  </>
)}
```

### Button Loading
```tsx
<Button disabled={isLoading}>
  {isLoading && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
  Save
</Button>
```

---

## Empty States

### No Results
```tsx
{leads.length === 0 && !isLoading && (
  <div className="flex flex-col items-center justify-center py-16 text-center">
    <Users className="h-12 w-12 text-muted-foreground mb-4" />
    <h3 className="text-lg font-medium mb-1">No leads found</h3>
    <p className="text-sm text-muted-foreground mb-4">
      {hasFilters 
        ? "Try adjusting your filters" 
        : "Get started by adding your first lead"
      }
    </p>
    {!hasFilters && (
      <Button onClick={() => setShowCreateDialog(true)}>
        <Plus className="mr-2 h-4 w-4" />
        Add Lead
      </Button>
    )}
  </div>
)}
```

---

## Error States

### Table Error
```tsx
{error && (
  <div className="flex flex-col items-center justify-center py-16 text-center">
    <AlertCircle className="h-12 w-12 text-destructive mb-4" />
    <h3 className="text-lg font-medium mb-1">Failed to load leads</h3>
    <p className="text-sm text-muted-foreground mb-4">
      {error.message}
    </p>
    <Button variant="outline" onClick={refetch}>
      <RefreshCw className="mr-2 h-4 w-4" />
      Try Again
    </Button>
  </div>
)}
```

---

## Accessibility

1. **Keyboard Navigation**: All interactive elements focusable
2. **Screen Reader Labels**: Aria labels on icon buttons
3. **Color Contrast**: WCAG 2.1 AA compliant
4. **Focus Indicators**: Visible focus rings
5. **Reduced Motion**: Respect `prefers-reduced-motion`

```tsx
<Button variant="ghost" size="icon" aria-label="More actions">
  <MoreHorizontal className="h-4 w-4" />
</Button>
```

---

## Critical Styling Notes

### Dropdown Backgrounds
**ALWAYS** ensure dropdowns have solid backgrounds:
```tsx
<DropdownMenuContent className="bg-popover z-50">
<SelectContent className="bg-popover">
<PopoverContent className="bg-popover">
```

### Z-Index Hierarchy
- Floating Bar: `z-50`
- Dropdowns: `z-50`
- Dialogs: `z-50` (handled by Radix)
- Tooltips: `z-50`

### Color Usage
**NEVER** use direct colors. Always use semantic tokens:
```tsx
// ❌ WRONG
className="text-white bg-black border-gray-200"

// ✅ CORRECT
className="text-foreground bg-background border-border"
```

### Dark Mode Support
All colors automatically adapt via CSS variables. Test both modes.
