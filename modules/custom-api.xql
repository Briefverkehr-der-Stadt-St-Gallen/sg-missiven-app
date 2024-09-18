xquery version "3.1";

(:~
 : This is the place to import your own XQuery modules for either:
 :
 : 1. custom API request handling functions
 : 2. custom templating functions to be called from one of the HTML templates
 :)
module namespace api="http://teipublisher.com/api/custom";

declare namespace tei="http://www.tei-c.org/ns/1.0";

(: Add your own module imports here :)
import module namespace rutil="http://e-editiones.org/roaster/util";
import module namespace errors = "http://e-editiones.org/roaster/errors";
import module namespace app="http://existsolutions.com/ssrq/app" at "app.xql";
import module namespace templates="http://exist-db.org/xquery/html-templating";
import module namespace pages="http://www.tei-c.org/tei-simple/pages" at "lib/pages.xql";
import module namespace config="http://www.tei-c.org/tei-simple/config" at "config.xqm";
import module namespace tpu="http://www.tei-c.org/tei-publisher/util" at "lib/util.xql";
import module namespace pm-config="http://www.tei-c.org/tei-simple/pm-config" at "pm-config.xql";
import module namespace dapi="http://teipublisher.com/api/documents" at "lib/api/document.xql";
import module namespace vapi="http://teipublisher.com/api/view" at "lib/api/view.xql";

declare variable $api:REGISTER-LUCENE-OPTIONS := map {
                    "leading-wildcard": "yes",
                    "filter-rewrite": "yes"
                };

(:~
 : Keep this. This function does the actual lookup in the imported modules.
 :)
declare function api:lookup($name as xs:string, $arity as xs:integer) {
    try {
        function-lookup(xs:QName($name), $arity)
    } catch * {
        ()
    }
};

declare function api:about($request as map(*)) {
    let $_ := util:log("info", "api:about")
    let $doc := $config:data-root  || "/about/about-the-edition-de.xml"
    let $_ := util:log("info", "api:about doc: " || $doc)
    let $xml := pages:load-xml($config:default-view, (), $doc)
    let $_ := util:log("info", "api:about xml: ")
    let $_ := util:log("info", $xml?data)
    
    let $template := doc($config:app-root || "/templates/pages/view.html")
    let $_ := util:log("info", "api:about template: ")
    let $_ := util:log("info", $template)
    let $model := map {
        "data": $xml?data,
        "odd": $config:default-odd,
        "view": $config:default-view,
        "template": $config:default-template

    }
    return
        templates:apply($template, api:lookup#2, $model, map {
            $templates:CONFIG_APP_ROOT : $config:app-root,
            $templates:CONFIG_STOP_ON_ERROR : true()
        })
};

declare function api:registerdaten($request as map(*)) {
    let $doc := xmldb:decode-uri($request?parameters?id)
    let $view := head(($request?parameters?view, $config:default-view))
    let $xml := pages:load-xml($view, (), $doc)
    let $template := doc($config:app-root || "/templates/facets.html")
    let $model := map {
        "data": $xml?data,
        "template": "facets.html",
        "odd": $xml?config?odd
    }
    return
        templates:apply($template, api:lookup#2, $model, map {
            $templates:CONFIG_APP_ROOT : $config:app-root,
            $templates:CONFIG_STOP_ON_ERROR : true()
        })
};

declare function api:abbreviations($request as map(*)) {
    let $lang := tokenize($request?parameters?language, '-')[1]
    let $blocks := $config:abbr//tei:dataSpec/tei:desc[@xml:lang=$lang]

    return
        for $block in $blocks
        return
            <div>
                <h3>{$block}</h3>

                {
                    for $item in $block/../tei:valList/tei:valItem
                    return
                        <li>
                            {$item/@ident/string()} = {($item/tei:desc[@xml:lang=$lang], $item/tei:desc[1])[1]/text()}
                        </li>
                }
            </div>
};

(: NOTE(DP): not in use due to performance :)
declare function api:bibliography($request as map(*)) {
    app:bibliography(<div/>, $request?parameters)
};


declare function api:partners($request as map(*)) {
    let $lang := $request?parameters?language
    for $partner in $config:partners//tei:dataSpec/tei:valList/tei:valItem return
        <div>
            <h3>
                { data($partner/@ident) }
            </h3>
            { $partner/tei:desc[@xml:lang=$lang] }
        </div>
};

declare function api:timeline($request as map(*)) {
    let $entries := session:get-attribute($config:session-prefix || '.hits')
    let $datedEntries := filter($entries, function($entry) {
            try {
                let $date := ft:field($entry, "date-min", "xs:date")
                return
                        exists($date) and year-from-date($date) != 1000
            } catch * {
                false()
            }
        })
    return
        map:merge(
            for $entry in $datedEntries
            group by $date := ft:field($entry, "date-min", "xs:date")
            return
                map:entry(format-date($date, "[Y0001]-[M01]-[D01]"), map {
                    "count": count($entry),
                    "info": ''
                })
        )
};

(:~
* retrieves all places as an json array 
* called by <pb-leaflet-map> component 
~:)
declare function api:places-all($request as map(*)) {
    let $places := doc($config:data-root || "/place/place.xml")//tei:listPlace/tei:place
    (: let $log := util:log("info", "api:places-all found '" || count($places) || "' places") :)
    return 
        array { 
            for $place in $places
            return
                if(string-length(normalize-space($place/tei:location/tei:geo)) > 0)
                then (
                    let $tokenized := tokenize($place/tei:location/tei:geo)
                    return 
                        map {
                            "latitude":$tokenized[1],
                            "longitude":$tokenized[2],
                            "label":$place/tei:placeName[@type='main']/string(),
                            "id":$place/@xml:id/string()
                        }
                ) else()
            }        
};
declare function api:split-list($request as map(*)) {
    let $search := normalize-space($request?parameters?search)    
    let $letterParam := $request?parameters?category
    let $limit := $request?parameters?limit
    (: let $log := util:log("info","api:split-list $search:"||$search || " - $letterParam:"||$letterParam||" - $limit:" || $limit )  :)
    let $reg-type := normalize-space($request?parameters?type)
    let $log := util:log("info","api:split-list: registry-type: " || $reg-type)
    let $items := api:query-register($reg-type,$search)
    let $log := util:log("info", "api:split-list found items: " || count($items))
    let $byLetter := 
        map:merge(
            for $item in $items
                let $name := ft:field($item, 'name-full')[1]
                order by $name
                group by $letter := substring($name, 1, 1) => upper-case()
                return
                    map:entry($letter, $item)
    )
    let $letter :=
        if ((count($items) < $limit) or $search != '') then
            "[A-Z]"
        else if (not($letterParam) or $letterParam = '') then
            head(sort(map:keys($byLetter)))
        else
            $letterParam
    let $itemsToShow :=
        if ($letter = '[A-Z]') then
            $items
        else
            $byLetter($letter)
    return
        map {
            "items": api:output-split-list-items($itemsToShow, $letter, $search, $reg-type),
            "categories":
                if ((count($items) < $limit)  or $search != '') then
                    []
                else array {
                    for $index in 1 to string-length('0123456789AÄBCDEFGHIJKLMNOÖPQRSTUÜVWXYZ')
                    let $alpha := substring('0123456789AÄBCDEFGHIJKLMNOÖPQRSTUÜVWXYZ', $index, 1)
                    let $hits := count($byLetter($alpha))
                    where $hits > 0
                    return
                        map {
                            "category": $alpha,
                            "count": $hits
                        },
                    map {
                        "category": "[A-Z]",
                        "count": count($items),
                        "label": <pb-i18n key="all">Alle</pb-i18n>
                    }
                }
        }
};

declare function api:query-register($reg-type as xs:string, $search as xs:string?) {
    (: let $_ := util:log("info","api:query-register $reg-type: " || $reg-type || " - $search " || $search) :)
    let $facet-string := if ($search and $search != '')
                        then ( 'name:(' || $search || '*)')
                        else ( 'name:*')
    return
    switch($reg-type) 
        case "people" return
            if ($search and $search != '') 
            then ( $config:register-person//(tei:person | tei:org | tei:personGrp)[ft:query(., $facet-string)] )
            else ( $config:register-person//(tei:person | tei:org | tei:personGrp)[ft:query(., $facet-string, $api:REGISTER-LUCENE-OPTIONS)] )
        case "place" return 
            if ($search and $search != '') 
            then ( $config:register-place//tei:place[ft:query(., $facet-string)] ) 
            else ( $config:register-place//tei:place[ft:query(., $facet-string, $api:REGISTER-LUCENE-OPTIONS)] )
        case "keyword" return 
            if ($search and $search != '') 
            then ( $config:register-keyword//tei:item[ft:query(., $facet-string)] )
            else ( $config:register-keyword//tei:item[ft:query(., $facet-string, $api:REGISTER-LUCENE-OPTIONS)] )
        default return
            error($errors:NOT_FOUND, "Register type " || $reg-type || " not found")
};

declare function api:output-split-list-items($list, $letter as xs:string, $search as xs:string?, $reg-type) {
    let $sorted := sort($list, "?lang=de-DE")
    return 
        array {
            for $item in $sorted
            let $name := ft:field($item, 'name-full')[1]
            return
                if(string-length($name)>0)
                then (
                    let $letterParam := if ($letter = "[A-Z]") then substring($name, 1, 1) else $letter
                    let $params := "&amp;category=" || $letterParam || "&amp;search=" || $search
                
                    return
                        <span class="{$reg-type} split-list-item">
                            <a href="{$name}?{$params}&amp;key={$item/@xml:id}">{$name}</a>
                            { api:output-split-list-items-details($item, $reg-type)}
                        </span>
            ) else()
    }
};

declare function api:output-split-list-items-details($item, $reg-type) {
    switch($reg-type) 
        case "people" return
            let $dates := $item/tei:note[@type="date"]/text()
            return if($dates) then ( <span class="dates"> ({$dates})</span> ) else ()
        case "organization" return
            let $type := substring-before($item/@type/string(),"/")
            return if ($type) then <span class="type"> ({$type})</span> else ()        
        case "place" return
            let $label := $item/@n/string()
            let $type := substring-before($item/tei:trait[@type="type"][1]/tei:label[@type='main']/text(), "/")
            let $coords := tokenize($item/tei:location/tei:geo)
            return (
                if (string-length($type) > 0) then <span class="type"> ({$type})</span> else (),
                if(string-length(normalize-space($item/tei:location/tei:geo)) > 0) 
                then (
                    element pb-geolocation {
                        attribute latitude { $coords[1] },
                        attribute longitude { $coords[2] },
                        attribute label { $label},
                        attribute emit {"map"},
                        attribute event { "click" },
                        if ($item/@type != 'approximate') then attribute zoom { 9 } else (),
                        
                        element iron-icon {
                            attribute icon {"maps:map" }
                        }
                    }
                ) 
                else ()
        )
        case "keyword" return ()
        default return
            error($errors:NOT_FOUND, "Register type " || $reg-type || " not found")    

};

declare function api:sort($items as array(*)*, $dir as xs:string) {
    let $sorted :=
        sort($items, "?lang=de-DE", function($entry) {
            $entry?1
        })
    return
        if ($dir = "asc") then
            $sorted
        else
            reverse($sorted)
};

declare function api:facets-search($request as map(*)) {
    let $value := $request?parameters?value
    let $query := $request?parameters?query
    let $type := $request?parameters?type
    let $lang := tokenize($request?parameters?language, '-')[1]

    let $_ := util:log("info", ("api:facets-search type: '", $type, "' - query: '" , $query, "' - value: '" , $value, "'"))    
    let $hits := session:get-attribute($config:session-prefix || ".hits")
    let $log := util:log("info", "api:facets-search: hits: " || count($hits))
    let $facets := ft:facets($hits, $type, ())
    let $log := util:log("info", "api:facets-search: $facets: " || count($facets))

    
    let $matches := 
        for $key in if (exists($request?parameters?value)) 
                            then $request?parameters?value 
                            else map:keys($facets)
            (: let $_ := util:log("info", "$key: " || $key || " type: " || $type) :)
            let $text := 
                switch($type) 
                    case "sender" 
                    case "recipient" 
                    case "name" return
                        $config:register-person/id($key)/tei:*[@type='main']/text()
                    case "exhib-place"
                    case "place" return
                        $config:register-place/id($key)/tei:placeName[@type='main']/text()
                    case "keyword" return
                        $config:register-keyword/id($key)/tei:label[@xml:lang='de'][@type eq 'main']/text()
                    case "filiation" return $key
                    case "material" return
                        let $i18n-path := $config:app-root || "/resources/i18n/app/" ||  $lang || ".json"
                        let $json := json-doc($i18n-path)
                        let $_ := util:log("info", "api:facets-search: material: $key : " || $key || " - $i18n-path: " || $i18n-path)
                        return
                            $json?($key)
                    default return 
                        let $_ := util:log("warn", "api:facets-search: default return, $type: " || $type)
                        return 
                            $key
            return 
                map {
                    "text": $text,
                    "freq": $facets($key),
                    "value": $key
                } 


           
        let $log := util:log("info", "api:facets-search: $matches: " || count($matches))
        let $filtered := filter($matches, function($item) {
            matches($item?text, '(?:^|\W)' || $request?parameters?query, 'i')
        })
        let $log := util:log("info", "api:facets-search: filtered $matches: " || count($filtered))
        return
            array { $filtered }
};

declare function api:prepare-entry($image as xs:string+) {
    let $url := 'https://media.sources-online.org/cantaloupe/iiif/2/sg-missiven!' || $image || '/full/full/0/default.jpg'
    let $object := hc:send-request(<hc:request method='GET' href="{$url}"></hc:request>)
    return
        <entry name="{$image}" type="binary" method="store">{$object[2]}</entry>
    };

declare function api:facsimiles($request as map(*)) {
    let $doc := xmldb:decode-uri($request?parameters?id)
    let $images := doc($config:data-root || '/' || $doc)//tei:pb/@facs
    let $entries := for $image in $images return api:prepare-entry($image)
    let $filename := "faksimile.zip"
    return
        response:stream-binary(
            compression:zip($entries, false()),
            'application/zip',
            $filename
        )
};

declare function api:create-actor($node as element()) {
    let $id := $node/@ref
    let $actor := $config:register-person/id($id)
    let $bibls := $actor/descendant::tei:listBibl/descendant::tei:ptr
    let $extRef := head(($bibls[@type = 'gnd'], $bibls[@type = 'viaf'], $bibls[@type = 'histhub'], $bibls[@type = 'ssrq']))
    let $ref := if ($extRef) then $extRef/@target else 'https://missiven.stadtarchiv.ch/namen/actor?key=' || $id
    return
         element {QName("http://www.tei-c.org/ns/1.0", $node/name())} {attribute {"ref"} {$ref}, $node/string()}
};

declare function api:create-place($node as element()) {
    let $id := $node/@ref
    let $place := $config:register-place/id($id)
    let $bibls := $place/descendant::tei:listBibl/descendant::tei:ptr
    let $ref := head(($bibls[@type = 'geonames'], $bibls[@type = 'gnd'], $bibls[@type = 'hls'], $bibls[@type = 'ssrq']))
    return
         element {QName("http://www.tei-c.org/ns/1.0", "placeName")} {attribute {"ref"} {$ref/@target}, $node/string()}
};


declare function api:corresp($request as map(*)) {
    let $collection := collection($config:data-default)
    let $uuid := 'e7909c5f-f4da-4abb-9b9f-0d7128231c77'
    let $last-modified-dates := for $x in $collection//tei:TEI return xmldb:last-modified($config:data-default, util:document-name($x))
    let $last-modified := max($last-modified-dates)
    return
        <TEI xmlns="http://www.tei-c.org/ns/1.0" xml:id="missiven-cmif-file">
        <teiHeader>
        <fileDesc>
            <titleStmt>
                <title>Briefverkehr der Stadt St. Gallen: Index der Briefe</title>
                <editor>Stadtarchiv und Vadianische Sammlung der Ortsbürgergemeinde St. Gallen</editor>
            </titleStmt>
            <publicationStmt>
                <publisher>Stadtarchiv und Vadianische Sammlung der Ortsbürgergemeinde St. Gallen</publisher>
                <idno type="url">https://missiven.stadtarchiv.ch/api/cmif</idno>
                <date when="{$last-modified}"/>
                <availability>
                    <licence target="https://creativecommons.org/licenses/by/4.0/">This file is licensed under the terms of the Creative-Commons-License CC BY-SA 4.0</licence>
                </availability>
            </publicationStmt>
            <sourceDesc>
                <bibl type="online" xml:id="{$uuid}">Briefverkehr der Stadt St. Gallen 1400-1650. Digitale Missivenedition. Hg. v. Stadtarchiv und Vadianischer Sammlung der Ortsbürgergemeinde St. Gallen 2024, <ref target="https://missiven.stadtarchiv.ch">https://missiven.stadtarchiv.ch</ref></bibl>
            </sourceDesc>
        </fileDesc>
            <profileDesc>
                {for $doc in $collection 
                    let $url := "https://missiven.stadtarchiv.ch/data/" || util:document-name($doc)
                    let $actionSent := $doc/descendant::tei:correspAction[@type eq 'sent']
                    let $actionReceived := $doc/descendant::tei:correspAction[@type eq 'received']
                    let $senders := ($actionSent/tei:persName, $actionSent/tei:orgName)
                    let $recipients := ($actionReceived/tei:persName, $actionReceived/tei:orgName)
                    return
                    <correspDesc ref="{$url}" source="#{$uuid}">
                        <correspAction type="sent">
                        {for $sender in $senders
                        return
                            api:create-actor($sender)}
                        {if ($actionSent/tei:placeName) then api:create-place($actionSent/tei:placeName) else ()}
                            <date when="{$actionSent/tei:date}"/>
                        </correspAction>
                        <correspAction type="received">
                        {for $recipient in $recipients 
                        return 
                            api:create-actor($recipient)}
                             {if ($actionReceived/tei:placeName) then api:create-place($actionReceived/tei:placeName) else ()}
                        </correspAction>
                    </correspDesc>}
            </profileDesc>
        </teiHeader>
        <text>
            <body>
                <p/>
            </body>
        </text>
    </TEI>
    };
