"""Draft filter dropdown; only Show deals or Clear all changes feed filters."""
import from "react" { useId }
import from .ui { ui, uiFont, formButton, formSecondary }

glob FILTER_PRICE_MAX: int = 20;
glob FILTER_TIMES: list[list[str]] = [["any", "Any time"], ["now", "Right now"], ["today", "Today"]];
glob FILTER_DIETS: list[list[str]] = [["vegetarian", "Vegetarian"], ["vegan", "Vegan"], ["gluten-free", "Gluten-free"], ["halal", "Halal"]];

def parseFilterMaximum(value: str) -> int {
    matched = new(RegExp, "^([0-9]+)-([0-9]+)$").exec(value or "");
    return min(int(matched[2]), FILTER_PRICE_MAX) if matched else FILTER_PRICE_MAX;
}

def FilterSection(title: str, children: any = None) -> JsxElement {
    return <fieldset style={{"border": 0, "margin": 0, "padding": 0, "minWidth": 0, "flexShrink": 0}}>
        <legend style={{"padding": 0, "marginBottom": 10, "fontSize": 12, "fontWeight": 800, "letterSpacing": 0.8, "textTransform": "uppercase", "color": ui.muted}}>{title}</legend>
        {children}
    </fieldset>;
}

def:pub OfferFilters(price: str, time: str, diets: list[str],
    onApply: Callable[[str, str, list[str]], None], onRefresh: Callable[[], None] | None = None,
    refreshing: bool = False) -> JsxElement {
    has opened: bool = False,
        maximum: int = parseFilterMaximum(price),
        when: str = time or "any",
        picked: list[str] = diets or [],
        panelHeight: float = 540.0,
        trigger: Ref[HTMLButtonElement] = Ref();
    panelId = useId();
    count = (1 if price else 0) + (1 if time and time != "any" else 0) + len(diets or []);
    maximumLabel = "Any price" if maximum == FILTER_PRICE_MAX else "$" + str(maximum) + " or less";
    matchingTimes = [pair[1] for pair in FILTER_TIMES if pair[0] == time];
    timeLabel = matchingTimes[0] if matchingTimes else "Any time";
    summary = " · ".join([("$" + str(parseFilterMaximum(price)) + " or less") if price else "Any price", timeLabel, *(diets or [])]);

    def toggle {
        # Every opening starts with the filters actually applied to the feed.
        if not opened {
            maximum = parseFilterMaximum(price);
            when = time or "any";
            picked = diets or [];
            tabbar = document.querySelector('[data-testid="app-tabbar"]') as HTMLElement | None;
            bottom = (tabbar.getBoundingClientRect().top if tabbar else 0) or window.innerHeight;
            if trigger.current {
                panelHeight = max(180.0, min(540.0, bottom - trigger.current.getBoundingClientRect().bottom - 12));
            }
        }
        opened = not opened;
    }
    def close {
        opened = False;
        if trigger.current { trigger.current.focus(); }
    }
    def apply {
        # Twenty means no ceiling; zero keeps free offers in the numeric range.
        onApply("" if maximum == FILTER_PRICE_MAX else "0-" + str(maximum), when, picked);
        close();
    }
    def clearAll { onApply("", "any", []); close(); }
    def toggleDiet(diet: str) {
        picked = [item for item in picked if item != diet] if diet in picked else [*picked, diet];
    }
    def refresh {
        opened = False;
        if onRefresh { onRefresh(); }
    }
    def keyDown(event: KeyboardEvent) {
        if opened and event.key == "Escape" { event.preventDefault(); close(); }
    }
    return <div className="ml-filters" style={{"fontFamily": uiFont, "color": ui.ink, "minWidth": 0, "position": "relative", "zIndex": 50 if opened else 1}} onKeyDown={keyDown}>
        <style>{"""
            .ml-filter-option{box-sizing:border-box;display:flex;align-items:center;gap:6px;min-height:44px;padding:8px;border:1px solid var(--ml-border);border-radius:10px;cursor:pointer;font-size:13px;background:var(--ml-surface)}
            .ml-filter-option:has(input:checked){border-color:var(--ml-accent);background:var(--ml-accent-soft);color:var(--ml-accent);font-weight:700}
            .ml-filter-option input{width:16px;height:16px;flex-shrink:0;accent-color:var(--ml-accent);margin:0}
            .ml-filter-time{justify-content:center;border:0;padding:8px 3px;background:transparent;font-size:13px;min-width:0;white-space:nowrap}
            .ml-filter-time input{position:absolute;width:1px;height:1px;opacity:0}
            .ml-filter-time:has(input:checked){background:var(--ml-surface);box-shadow:0 1px 4px var(--ml-shadow)}
            .ml-filter-time:focus-within{outline:3px solid var(--ml-focus);outline-offset:1px}
            .ml-price-slider{box-sizing:border-box;width:100%;height:44px;margin:0;accent-color:var(--ml-accent);cursor:pointer}
        """}</style>
        <div className="ml-feed-toolbar" style={{"display": "flex", "gap": 10, "alignItems": "stretch"}}>
            <button ref={trigger} type="button" aria-expanded={opened} aria-controls={panelId} aria-label={"Filters" + ((", " + str(count) + " active") if count else "") + ": " + summary} onClick={toggle}
                style={{**formSecondary, "flex": 1, "display": "flex", "alignItems": "center", "justifyContent": "space-between", "gap": 6, "minHeight": 50, "padding": "12px 10px", "fontSize": 14, "borderRadius": 14}}>
                <span style={{"display": "flex", "alignItems": "center", "gap": 6}}>
                    <svg aria-hidden="true" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8"><path d="M4 7h16M4 17h16"/><circle cx="9" cy="7" r="3" fill={ui.white}/><circle cx="15" cy="17" r="3" fill={ui.white}/></svg>
                    Filters
                    {if count > 0 { <span style={{"borderRadius": 6, "background": ui.maize, "color": ui.onMaize, "fontSize": 12, "padding": "2px 6px"}}>{count}<span style={{"position": "absolute", "width": 1, "height": 1, "overflow": "hidden"}}> active</span></span> }}
                </span>
                <svg aria-hidden="true" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" style={{"flexShrink": 0, "transform": "rotate(180deg)" if opened else None}}><path d="m6 9 6 6 6-6"/></svg>
            </button>
            <button type="button" disabled={refreshing} onClick={refresh} style={{**formSecondary, "flex": 1, "minHeight": 50, "padding": "12px 8px", "fontSize": 14, "whiteSpace": "nowrap"}}>{"Refreshing..." if refreshing else "Refresh offers"}</button>
        </div>
        {if opened {
            <div id={panelId} role="region" aria-label="Offer filters" style={{"boxSizing": "border-box", "position": "absolute", "top": "calc(100% + 8px)", "left": 0, "right": 0, "maxHeight": panelHeight, "overflow": "hidden", "border": "1px solid " + ui.line, "borderRadius": 14, "boxShadow": "0 18px 40px -12px var(--ml-shadow)", "background": ui.white, "display": "flex", "flexDirection": "column"}}>
                <div style={{"overflowY": "auto", "minHeight": 0, "padding": 16, "display": "flex", "flexDirection": "column", "gap": 16}}>
                    <FilterSection title="Maximum price">
                        <div style={{"display": "flex", "justifyContent": "space-between", "alignItems": "baseline", "gap": 12}}><span style={{"fontSize": 13, "color": ui.muted}}>Per offer</span><output style={{"fontSize": 20, "fontWeight": 800, "color": ui.navy, "fontVariantNumeric": "tabular-nums"}}>{maximumLabel}</output></div>
                        <input className="ml-price-slider" type="range" min="0" max={str(FILTER_PRICE_MAX)} step="1" value={maximum} aria-label="Maximum price" aria-valuetext={maximumLabel} onChange={lambda (event: ChangeEvent) { maximum = int(event.target.value); }}/>
                        <div style={{"display": "flex", "justifyContent": "space-between", "fontSize": 12, "color": ui.muted}}><span>$0</span><span>Any price</span></div>
                    </FilterSection>
                    <FilterSection title="When"><div style={{"display": "grid", "gridTemplateColumns": "repeat(3,minmax(0,1fr))", "gap": 3, "padding": 3, "borderRadius": 12, "background": ui.inset}}>
                        {for pair in FILTER_TIMES { <label key={pair[0]} className="ml-filter-option ml-filter-time"><input type="radio" name={panelId + "-when"} checked={when == pair[0]} onChange={lambda { when = pair[0]; }}/>{pair[1]}</label> }}
                    </div></FilterSection>
                    <FilterSection title="Diet preferences"><div style={{"display": "grid", "gridTemplateColumns": "repeat(auto-fit,minmax(110px,1fr))", "gap": 8}}>
                        {for pair in FILTER_DIETS { <label key={pair[0]} className="ml-filter-option"><input type="checkbox" checked={pair[0] in picked} onChange={lambda { toggleDiet(pair[0]); }}/>{pair[1]}</label> }}
                    </div></FilterSection>
                </div>
                <div style={{"display": "flex", "gap": 8, "background": ui.white, "padding": 12, "borderTop": "1px solid " + ui.line, "flexShrink": 0}}>
                    <button type="button" onClick={clearAll} style={{**formSecondary, "flex": 1, "padding": "12px 8px"}}>Clear all</button>
                    <button type="button" onClick={apply} style={{**formButton, "flex": 1, "padding": "12px 8px"}}>Show deals</button>
                </div>
            </div>
        }}
    </div>;
}
