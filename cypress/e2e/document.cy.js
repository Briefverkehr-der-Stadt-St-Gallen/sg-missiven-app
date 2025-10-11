describe('Single document check', () => {
  beforeEach('loads', () => {
    cy.intercept({ resourceType: /xhr|fetch/ }, { log: false })
    cy.visit('data/stasg_missiv_00006.xml?mode=off&view=single&odd=rqzh')
  })


  // Metadata tests

  it('Check meta title', () => {
    cy.title()
    .should('not.be.empty')
    .should('eq', 'St. Galler Missiven: StadtASG Missive, Nr. 6')
  })

  it.skip('Check meta description', () => {
    cy.get('meta[name="description"]')
      .should('have.attr', 'content')
      .and('not.be.empty')
  })

  it('Check meta url', () => {
    cy.get('link[rel="canonical"]')
      .invoke('attr', 'href')
      .then((href) => {
        expect(href.startsWith('https://missiven.stadtarchiv.ch/')).to.be.true
      })
  })


// Content tests

  it('Document title is in the header', () => {
    cy.contains('h1', 'Ulrich Zeph an Bürgermeister und Rat zu St. Gallen').should('be.visible')
  })


// Merging the text in the document with data from registers test

  it('Person of name Ulrich Zeph is in register', () => {
    cy.get('ul.persons')
      .contains('a', 'Zeph, Ulrich (1421–)')
      .should('exist')
      .should('have.length', 1)
      .and('have.attr', 'href', '../namen/Zeph, Ulrich?key=stadtasg-actors-6')
      .click()
    cy.wait(10)
    cy.contains('h1', 'Name: Zeph, Ulrich').should('be.visible')
      .should('have.id', 'locations');
  })

  it('Person of name Ulrich Zeph is mentioned in the text', () => {
    cy.get('#content')
      .contains('a', 'Zeph, Ulrich (1421–)')
      .should('exist')
      .should('have.length', 1)
      .and('have.attr', 'href', '../namen/Zeph, Ulrich?key=stadtasg-actors-6')
    // cy.get('[href$="per017829"]')
    //  .contains('Zeph, Ulrich')
  })

  it('Person of name Ulrich Zeph is highlighted in the text after checking name in register', () => {
    // clicking name in register list
    cy.get('pb-popover[data-ref=stadtasg-actors-6]')
      // checking highlight before
      .should('not.have.class', 'highlight')
    cy.get('li[data-ref=stadtasg-actors-6]')
      .find('div#checkboxContainer')
      .click()
    // checking highlight after
    cy.get('pb-popover[data-ref=stadtasg-actors-6]')
      .should('have.class', 'highlight')
  })

  it('organisation of name Bürgermeister und Rat zu St. Gallen (1426–) is in register', () => {
    cy.get('ul.persons')
      .contains('a', 'Bürgermeister und Rat zu St. Gallen')
      .should('exist')
      .should('have.length', 1)
      .and('have.attr', 'href', '../namen/Bürgermeister und Rat zu St. Gallen?key=stadtasg-actors-148')
      .click()
    cy.wait(10)
    cy.contains('h1', 'Name: Bürgermeister und Rat zu St. Gallen').should('be.visible')
      .should('have.id', 'locations');
  })

  it('Organisation of name Bürgermeister und Rat zu St. Gallen is mentioned in the text', () => {
    cy.get('#content')
      .find('pb-popover[data-ref="stadtasg-actors-148"]')
      .find('span[slot="alternate"]')
      .should('exist')
      .should('contain', 'Organisation: ')
      .should('contain', 'Bürgermeister und Rat zu St. Gallen')
      .first()
      .within(() => {
          cy.get('a[href="../namen/Bürgermeister und Rat zu St. Gallen?key=stadtasg-actors-148"]').should('exist');
          });
  })



// Navigation tests 

// skipped because of error, see https://gitlab.existsolutions.com/missiven/stgm/-/issues/42
  it.skip('Prev via clicking', () => {
    cy.get('pb-link#prev')
      .filter(':contains("zum vorherigen Stück im Band")').eq(0)
      .click()
      cy.wait(10)
    cy.contains('h1', '8.2.1421').should('be.visible')
  })


 it.skip('Next via clicking', () => {
    cy.get('pb-navigation[keyboard=right]')
      .filter(':contains("zum nächsten Stück im Band")').eq(0)
      .click()
      cy.wait(10)
    cy.contains('h1', '17.4.1421').should('be.visible')
  })

// Images tests

})