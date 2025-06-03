xquery version "3.1";

module namespace app="http://existsolutions.com/ssrq/app";

import module namespace templates="http://exist-db.org/xquery/html-templating";
import module namespace config="http://www.tei-c.org/tei-simple/config" at "config.xqm";
import module namespace common="http://www.tei-c.org/tei-simple/xquery/functions/ssrq-common" at "ext-common.xql";
import module namespace pm-config="http://www.tei-c.org/tei-simple/pm-config" at "pm-config.xql";
import module namespace nav="http://www.tei-c.org/tei-simple/navigation/tei" at "navigation-tei.xql";
import module namespace http="http://expath.org/ns/http-client" at "java:org.expath.exist.HttpClientModule";
import module namespace query="http://www.tei-c.org/tei-simple/query" at "query.xql";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace expath="http://expath.org/ns/pkg";

declare %templates:replace
    function app:show-if-logged-in($node as node(), $model as map(*)) {
        let $user := request:get-attribute($config:login-domain || ".user")
        return
            if ($user) then
                element { node-name($node) } {
                    $node/@*,
                    templates:process($node/*[1], $model)
                }
            else ()
};

declare %templates:replace
    function app:show-if-not-logged-in($node as node(), $model as map(*)) {
        let $user := request:get-attribute($config:login-domain || ".user")
        return
            if (not($user)) then
                element { node-name($node) } {
                    $node/@*,
                    templates:process($node/*[1], $model)
                }
            else ()
};

declare 
    %templates:wrap
function app:document-count($node as node(), $model as map(*)) {
    <pb-i18n key="browse.items" options='{{"count": "{count($model?all)}"}}'></pb-i18n>
};

declare function app:list-volumes($node as node(), $model as map(*), $root as xs:string?) {
    for $hits in $model?all
    group by $volume := ft:field($hits, "volume")
    let $volumeInfo := collection($config:data-root)/tei:TEI[@type='volinfo'][.//tei:seriesStmt/tei:idno[@type="machine"] = "SSRQ_" || $volume]
    let $order := $volumeInfo/@n
    let $count := count($hits)
    order by $order
    return
        if ($count > 0) then
            <div class="volume">
                <a href="#" data-collection="{$volume}">{ 
                    $pm-config:web-transform($volumeInfo/tei:teiHeader/tei:fileDesc, map { "root": $volume, "count": $count, "view": "volumes" }, $config:odd)
                }</a>
            </div>
        else
            ()
};

declare function app:api-lookup($api as xs:string, $list as map(*)*, $param as xs:string) {
    let $lang := (session:get-attribute("ssrq.lang"), "de")[1]
    let $iso-639-3 :=
    map {
        'de'     : 'deu',
        'fr'     : 'fra',
        'it'     : 'ita',
        'en'     : 'eng'
    }
    let $refs := string-join(for $item in $list return $item?ref, ",")
    let $request := <http:request method="GET" href="{$api}?{$param}={$refs}&amp;lang={$iso-639-3($lang)}"/>
    let $response := http:send-request($request)
    return
        if ($response[1]/@status = "200") then
            let $json := parse-json(util:binary-to-string($response[2]))
            return
                $json?info
        else
            ()
};

declare function app:api-lookup-xml($api as xs:string, $list as map(*)*, $param as xs:string) {
    let $lang := (session:get-attribute("ssrq.lang"), "de")[1]
    let $iso-639-3 :=
    map {
        'de'     : 'deu',
        'fr'     : 'fra',
        'it'     : 'ita',
        'en'     : 'eng'
    }
    let $refs := string-join(for $item in $list return $item?ref, ",")
    let $request := <http:request method="GET" href="{$api}?{$param}={$refs}&amp;lang={$iso-639-3($lang)}"/>
    let $response := http:send-request($request)
    return
        if ($response[1]/@status = "200") then
            $response[2]
        else
            ()
};

declare function app:api-keys($refs as xs:string*) {
    for $id in $refs
    group by $ref := substring($id, 1, 9)
    (: group by $ref := replace($id, "^([^\.]+).*$", "$1") :)
    return
        map {
            "ref": $ref,
            "name": $id[1]
        }
};

declare function app:meta($node as node(), $model as map(*)) {
    let $data := config:get-document($model?doc)
    let $site := config:expath-descriptor()/expath:title/string()
    let $title := $data//tei:fileDesc/tei:titleStmt/tei:title => normalize-space()
    let $description := $data//tei:profileDesc/tei:abstract => normalize-space()
    return
        map {
            "title": string-join(($site, $title), ': '),
            "description": $description,
            "language": "de",
            "url": "https://missiven.stadtarchiv.ch/" || $model?doc,
            "site": $site
        }
};

declare 
    %templates:wrap
function app:meta-title($node as node(), $model as map(*)) {
    $model?title
};

(:~
 : Display a facsimile thumbnail in the collection list next to each document, if available,
 : and link it to the document
 :)
declare
    %templates:replace
function app:short-header-link($node as node(), $model as map(*)) {
    let $work := root($model("work"))/*
    let $href := config:get-identifier($work)
    let $thumbnail-src := ($work//tei:body//tei:pb/@facs)[1]

    return (
        if (exists($thumbnail-src))
        then (
            element { node-name($node) } {
                $node/@*,
                attribute href { $href },
                element img {
                    attribute src { $config:iiif-base-uri || $thumbnail-src || '/full/178,/0/default.jpg'},
                    attribute class { 'document-thumbnail-image' },
                    templates:process($node/node(), $model)
                }
            }
        )
        else ()
    )
};

declare 
    %templates:wrap
function app:volume-title($node as node(), $model as map(*)) {
    if (not($model?root) or $model?root = "") then
        ()
    else
        let $info := collection($config:data-root || "/" || $model?root)/tei:TEI[@type='volinfo']
        return
            replace(normalize-space($info//tei:titleStmt/tei:title/string()), "^.*?([^:]+)$", "$1")
};

declare
    %templates:wrap    
    %templates:default("key","")
function app:load-person($node as node(), $model as map(*), $key as xs:string) {
    let $person := $config:register-person/id(xmldb:decode($key))
    (: let $log := util:log("info", "app:load-person $name: " || $person/tei:persName[@type="full"]/text() || " - $key:" || $key) :)    
    let $date := if ($person/tei:birth) then $person/tei:birth/@when else $person/tei:event[@type eq 'start']/@when
    return 
        map {
                "title": $person/*[@type="main"]/text(),
                "key":$key,
                "date":common:format-date($date),
                "description": $person/tei:note[@type="description"]/tei:p,
                "sources": $person/tei:note[@type="sources"]/tei:p,
                "data": $person
        }    
};

declare
    %templates:wrap    
    %templates:default("key","")
function app:load-keyword($node as node(), $model as map(*), $key as xs:string) {
    let $keyword := doc($config:data-root || "/keyword/keyword.xml")//tei:item[@xml:id = xmldb:decode($key)]
    (: let $log := util:log("info", "app:load-keyword tei:desc: " || $keyword/tei:desc[@xml:lang="deu"]/text() || " - $key:" || $key) :)
    
    return 
        map {
                "title": $keyword/tei:label[@type='main'][@xml:lang="de"]/text(),
                "description": $keyword/tei:note[@type="description"]/tei:p,
                "sources": $keyword/tei:note[@type="sources"],
                "data": $keyword,
                "key":$key
        }
};


declare
    %templates:wrap    
    %templates:default("name","")
    %templates:default("key","")
function app:load-organization($node as node(), $model as map(*), $name as xs:string, $key as xs:string) {
    let $log := util:log("info", "app:load-organization $name: " || $name || " - $key:" || $key)
    let $org := doc($config:data-root || "/organization/organization.xml")//tei:org[@xml:id = xmldb:decode($key)]
    return 
        map {
                "title": $org/tei:orgName[@type eq 'main']/text(),
                "key":$key,
                "type":$org/@type/string()
        }    
};



declare
    %templates:wrap    
    %templates:default("name","")
    %templates:default("key","")
function app:load-place($node as node(), $model as map(*), $name as xs:string, $key as xs:string) {
    let $log := util:log("info", "app:load-place $name: " || $name || " - $key:" || $key)
    let $lang := "de"
    let $place := doc($config:data-root || "/place/place.xml")//tei:listPlace/tei:place[@xml:id = xmldb:decode($key)]
    let $typeId := $place/@type
    let $type := doc($config:data-root || "/place/place.xml")//tei:classDecl/tei:taxonomy/tei:category[@xml:id=$typeId]/tei:catDesc[@xml:lang=$lang]/text()
    let $country := $place/tei:location/tei:country[@xml:lang=$lang]/string()
    let $optCountry := if (string-length($country) > 0) then (" (" || $country || ")") else ("")
    let $title := $place/tei:placeName[@type="main"]/string()
    let $heading := $place/tei:placeName[@type="full"]/string() || $optCountry
    let $description := $place/tei:note[@type="description"]/tei:p
    let $sources := $place/tei:note[@type="sources"]
    let $map := map {
        "key": $key,
        "title": $title,
        "heading": $heading,
        "optCountry": $optCountry,
        "type": $type,
        "description": $description,
        "sources": $sources,
        "data": $place
    }
    
(:    let $log := util:log("info", "app:load-place $title:" || $title):)
(:    let $log := util:log("info", "app:load-place $geo:" || $place//tei:geo/text()):)
    return 
        if(string-length(normalize-space($place//tei:geo/text())) > 1)
        then(
            let $geo-token := tokenize($place//tei:geo/text(), " ")
            return map:merge(($map, map {
                "latitude": $geo-token[1],
                "longitude": $geo-token[2]
            }))
        )
        else (
            $map
        )
};

declare %templates:default("type", "") %templates:wrap function app:place-type($node as node(), $model as map(*), $name as xs:string) {
    $model?type
};

declare %templates:default("description", "")  function app:place-description($node as node(), $model as map(*), $name as xs:string) {
    let $description := $model?description
    return
        $description
};

declare %templates:default("sources", "")  function app:place-sources($node as node(), $model as map(*), $name as xs:string) {
    let $sources := $model?sources
    return
        $sources
};

declare
    %templates:replace
    %templates:default("name", "")
function app:bibl-ptr($node as node(), $model as map(*), $name as xs:string) {
    let $data := $model?data
    let $meta-information :=
            for $entry in $data/tei:listBibl/tei:bibl[not(exists(@type))]/tei:ptr
                order by $entry/@type ascending
                (: let $log := util:log("info", "app:place-ptr: type: " || $entry/@type) :)
                return
                        element li {
                            element a {
                                attribute href {$entry/@target/string()},
                                attribute target { "blank_"},
                                <pb-i18n key="links.{$entry/@type/string()}">{$entry/@type/string()}</pb-i18n>
                            }
                        }
    return
        if (count($meta-information) = 0)
        then ()
        else
            <details class="metadaten">
                <summary>
                    <pb-i18n key="further-information"></pb-i18n>
                </summary>
                <ul>{ $meta-information }</ul>
            </details>
};

declare 
    %templates:wrap  
    %templates:default("name", "")  
function app:show-map($node as node(), $model as map(*), $name as xs:string) {
    let $key := $model?key
    let $place :=  doc($config:data-root || "/place/place.xml")//tei:listPlace/tei:place[@xml:id = $key]
    return
        if(string-length(normalize-space($place//tei:geo/text() ) ) > 1)
        then (
            let $log := util:log("info", "show map" )
            return
                templates:process($node/*, $model)
        ) else (
            <ul>
                <li><pb-i18n key="missing-geo-data"/></li>
            </ul>
        ) 
};

declare %templates:default("name", "")  function app:person-name($node as node(), $model as map(*), $name as xs:string) {
    $model?title
};

declare %templates:default("name", "")  function app:person-date($node as node(), $model as map(*), $name as xs:string) {
    $model?date 
};

declare %templates:default("description", "")  function app:person-description($node as node(), $model as map(*), $name as xs:string) {
    let $description := $model?description
    return
        $pm-config:web-transform(
                            $description,
                            map { 
                                "root": $description, 
                                "view": "single", 
                                "header": "person-description", 
                                "webcomponents": 7},
                                'rqzh.odd')
};

declare %templates:default("sources", "")  function app:person-sources($node as node(), $model as map(*), $name as xs:string) {
    let $sources := $model?sources
    return
        $sources
};

declare %templates:wrap %templates:default("name", "")  
function app:keyword-name($node as node(), $model as map(*), $name as xs:string) {
    $model?title
};

declare %templates:wrap %templates:default("description", "")  
function app:keyword-description($node as node(), $model as map(*), $description as xs:string) {
    $model?description
};

declare %templates:default("sources", "")  function app:keyword-sources($node as node(), $model as map(*), $name as xs:string) {
    $model?sources
};

declare %templates:default("name", "")  function app:organization-name($node as node(), $model as map(*), $name as xs:string) {
    let $name := if($model?name) then ($model?name) else xmldb:decode($name)
    let $date := 
            if ( string-length( $model?type ) > 0 ) 
            then ( "(" || substring-before($model?type,"/") || ")" ) 
            else ()
    return
        $name || " " || $date
};



declare function app:person-link($node as node(), $model as map(*)) {
    let $key := $model?key
    let $name := $model?title
    return
        element a { 
            attribute href { "https://www.ssrq-sds-fds.ch/persons-db-edit/?query=" || $key },
            attribute target { "_blank"},
            <span>{xmldb:decode($name)} <pb-i18n key="at-ssrq-sds-fds"/></span>
        }    
};

declare %templates:default("name", "")  function app:place-link($node as node(), $model as map(*), $name as xs:string) {
    let $key := $model?key
    let $name := if($model?name) then ($model?name) else $name
    return
        element a {
            attribute href { "https://www.ssrq-sds-fds.ch/places-db-edit/views/view-place.xq?id=" || $key },
            attribute target { "_blank"},
            <span>{xmldb:decode($name)} <pb-i18n key="at-ssrq-sds-fds"/></span>
        }    
};

declare %templates:wrap 
        %templates:default("type", "place") 
function app:mentions($node as node(), $model as map(*), $type as xs:string) {
    let $key := $model?key
    let $matches :=
        switch ($type)
        case "place" 
            return (collection($config:data-default)/tei:TEI//tei:text//tei:placeName[@ref = $key], collection($config:data-default)/tei:TEI//tei:text//tei:origPlace[@ref = $key])
        case "person"
        case "personGrp"
            return (collection($config:data-default)/tei:TEI//tei:text//tei:persName[@ref = $key], collection($config:data-default)/tei:TEI//tei:text//tei:orgName[@ref = $key])
        case "keyword"
        case "term"
            return collection($config:data-default)//tei:term[@ref = $key]
        default
            return util:log("warn", "app:mentions: unknown type: " || $type)
    return
        element div {
            element h3 {
                element pb-i18n { 
                    attribute key {"mentions-of"}
                },
                " ",
                $model?title
            },
            if (count($matches) ne 0)
            then (
                for $match in $matches
                group by $file := util:document-name($match)
                order by $file ascending
                let $root := root($match[1])
                let $sendAction:= $root//tei:correspAction[@type='sent']
                let $date := $sendAction/tei:date
                let $sendersIds := ($sendAction/tei:persName/@ref, $sendAction/tei:orgName/@ref)
                let $sendersNames := for $id in $sendersIds return $config:register-person/id($id)/*[@type eq 'main']
                let $sendersFormatted := if (count($sendersIds) eq 1) then $sendersNames else if (count($sendersIds) <= 3) then string-join($sendersNames, '; ') else string-join(subsequence($sendersNames, 1, 3), '; ') || ' u.a.'
                let $receiveAction := $root//tei:correspAction[@type='received']
                let $recipientsIds := ($receiveAction/tei:persName/@ref, $receiveAction/tei:orgName[not(@ref = 'stadtasg-actors-148')]/@ref)
                let $recipientsNames := for $id in $recipientsIds return $config:register-person/id($id)/*[@type eq 'main']
                let $recipientsFormatted := if (count($recipientsIds) eq 1) then $recipientsNames else if (count($recipientsIds) <= 3) then string-join($recipientsNames, '; ') else string-join(subsequence($recipientsNames, 1, 3), '; ') || ' u.a.'
                let $title := if ($recipientsIds) then string-join(($root//tei:titleStmt/tei:title/string(), common:format-date($date), ($sendersFormatted || ' an ' || $recipientsFormatted)), ', ') else 
                    string-join(($root//tei:titleStmt/tei:title/string(), common:format-date($date), $sendersFormatted), ', ')
                let $relpath := config:get-relpath($root)
                return
                    element div {
                        element p {
                            <a href="{$config:context-path}/{$relpath}">{$title}</a>
                        },
                        if($type != "keyword") then (
                        element ul {
                            for $hit in $match
                            group by $text := normalize-space(string-join($hit/text(), ""))
                            order by $text
                            return 
                                    element li {
                                        $text
                                    }

                        }) else ()
                    }
            ) else (
            )
        }
};

(:~ Helper function for Literaturverzeichnis 
 : The Introduction blurb of the bibliography  
 : TODO(DP): need confirmation that this is the blurb wanted by client
:)
declare function app:bibl-blurb() as element(p) {     
    let $blurb := $app:LITERATUR//tei:body/tei:div/tei:div/tei:div/tei:p/text()
    return
        <p>{$blurb}</p>
};

(:~ Helper function for Literaturverzeichnis 
 : Not all links go to BSG, but to … ?  
 : TODO(DP): find out new link target for non-BSG linksm should also be perma links no?
 :)
declare function app:bibl-link($idno as xs:string) as xs:string {     
    let $chbsg := 'http://permalink.snl.ch/bib/'
    let $non-bsg := '/suche/detail/'
    
    return
        if ($idno ! starts-with(., 'chbsg')) then ($chbsg || $idno)
        else ($non-bsg || $idno) 
};

(:~ Helper function for Literaturverzeichnis  
 : Table headers for bibliography tables  
 : without 'Zitiert in'
 : TODO(DP): add i18n entries <pb-i18n key="bibliography" /> 
 : @see app:bibl-quoted
 :)
declare function app:bibl-thead() as element(thead) {
    let $column-headings := ('Kurztitel', 'Bibliografische Angaben', 'Nachweis BSG')
    return
        <thead>
            <tr>
                { for $heading in $column-headings
                    return
                        <th>{$heading}</th>
                }
            </tr>
        </thead>

};

(:~ Helper function for Literaturverzeichnis 
 : Kurztitle
 :)
declare function app:bibl-short($node as node()) as element(td) {
    <td>{$node/tei:*/tei:title[@type="short"]/text()}</td>        
};

(:~ Helper function to get the named editors of edited volumes 
 : note  not all EV have named editors in their monogr
 : @param $secondary the container Work (Volume for article in Edited Volume) 
 : @see app:bibl-full
 :)
declare function app:bibl-editors($secondary as node()) as xs:string* {
        if (exists($secondary/tei:author)) 
        then (string-join($secondary/tei:author, '; ')) 
        else ()
};

(:~ Helper function to get the named imprint  of edited volumes 
 : note: some imprints are missing in source data
 : @see app:bibl-full
 :)
declare function app:bibl-ev-imprint($secondary as node()) as xs:string* {
    $secondary/tei:title[1]/string() || ", " || $secondary//tei:pubPlace[1] || " " || $secondary//tei:date[1] || ", " || $secondary//tei:biblScope[@unit = 'page']
};

(:~ Helper function to get the named imprint  of journals 
 : note some imprints are missing in source data
 : @param $secondary the container Work (journal for journal article)
 : @see app:bibl-full
 :)
declare function app:bibl-ja-imprint($secondary as node()) as xs:string* {
    $secondary/tei:title[1]/string() || ' ' || $secondary//tei:biblScope[@unit ='issue'] || ", " || $secondary//tei:date[1] || ", " || $secondary//tei:biblScope[@unit = 'page']
};

(:~ Helper function for Literaturverzeichnis 
 : Vollständige Bibliografische Angaben
 :
 : Monographie:
 : Nachname, Vorname: Titel, Erscheinungsort Jahr.
 :
 : Beitrag in Sammelband:
 : Nachname, Vorname: Titel, in: Vorname Nachname (Hg.), Titel Sammelband, Erscheinungsort Jahr, Seitenzahlen.
 :
 : Beitrag in Zeitschrift:
 : Nachname, Vorname: Titel, in: Titel Zeitschrift Nummer, Jahr, Seitenzahlen.
 :
 : TODO(DP): 
 : - Data Source is still missing datapoints:
 : - make display prettier for missing data no "Titel , , 313-4.
 : - configure index for faster loading
 :)
declare function app:bibl-full($node as node(), $type as xs:string) as xs:string {
    (: get primary bibliographical element for author and title (all) :)
    let $main := $node/*/tei:title[@type="short"]/..
    let $authors := string-join($main/tei:author, '; ')
    let $title := $main/tei:title[@type="full"]/string()

    (: assemble shared components :)
    let $start-all := $authors || ": " || $title || ", "

    (: get secondary for JA and EV :)
    let $secondary := if ($type eq 'W') then () else ($node/tei:monogr)
    
    return
        switch($type)
            case ('W') return $start-all || $node//tei:pubPlace[1] || " " || $node//tei:date || "."
            case ('EV') return $start-all || "in: " || app:bibl-editors($secondary) || " (Hg.) " || app:bibl-ev-imprint($secondary) || "."
            case ('JA') return $start-all || "in: " || app:bibl-ja-imprint($secondary) || "."         
        default return ()   
};

(:~ Helper function for Literaturverzeichnis 
 : @param $list one of the two listBibls in the Bibliographie file
 : @return caption containing the header belonging to that listBibl
 :)
declare function app:bibl-caption($list as node()) as xs:string {
        $list/../../tei:head/string()
};

(:~ Helper function for Literaturverzeichnis 
 : Checks for appearance of permalink in the bibliography within the data repo and returns the containing documents as links.
 : note $config:data-collections as better target for this function.
 : TODO(DP): what is the new link target for the quotations
 : @see app:bibl-link
 : @param permalink based on the xml:id of the quoted work to be found in the bibliography. 
 : @return a list of editions containing the quotations.
 :)
declare %private function app:bibl-quoted($permalink as xs:string) as element(ul) {
   <ul> {
    let $quotes := $config:data-root//tei:bibl/tei:ref[@target = $permalink] ! base-uri(.) 
        ! substring-after(., 'stgm-data/') 
        ! substring-before(., '/') 
        => distinct-values()
    for $q in $quotes
    return
        <li><a href="." target="_blank">{$q}</a></li>    
   } </ul>
};

(:~ Generate tables for Literaturverzeichnis
 : Die Seite enthält: 
 : Kurztitel (ausschlaggebend für alphabetische Auflistung); 
 : vollständige bibliographische Angaben; 
 : Link zur BSG; 
 : Editionsstück(e) in dem der Literaturtitel zitiert wird. 
 : @see http://www.rechtsquellen-online.ch/startseite/literaturverzeichnis 
 : @see data/SSRQ_ZH_NF_Bibliographie_integral.xml
 : @return div element
 :)
declare
%templates:wrap
function app:bibliography($node as node(), $model as map(*)) as element(div){
    <div>
        { app:bibl-blurb() },
        {
            for $list in $app:LITERATUR//tei:body/*/*/*/tei:listBibl
            return
            <table>
                { app:bibl-thead() }
                <caption>{ app:bibl-caption($list) }</caption>
                <tbody>
                {
                    for $entry in $list/tei:biblStruct
                    let $id := data($entry/@xml:id)
                    let $type := data($entry/@type)
                    let $short := $entry/*/tei:title[@type = "short"]/text()
                    order by $short
                    return
                            <tr id="{ $id }">
                                <td>{ $short }</td>
                                <td>{ app:bibl-full($entry, $type) }</td>
                                <td><a href="{ app:bibl-link($id) }" target="_blank">BSG</a></td>
                            </tr>
                }
                </tbody>
            </table>
        }
    </div>
};


declare
    %templates:wrap
function app:set-default-params($node as node(), $model as map(*)) {
    let $new-model := map:merge(($model, 
                                map { "type": "document" },
                                map { "sort": "send-date" },
                                map { "subtype": "document" }
                            ))    
    return
        templates:process($node/*, $new-model)
};

declare 
%templates:wrap
function app:current-date($node as node(), $model as map(*)) {
    let $date := format-date(current-date(), '[Y0001]-[M01]-[D01]')
    return
    common:format-date($date, 'de')};
