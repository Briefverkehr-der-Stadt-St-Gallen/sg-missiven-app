describe('Single document check', () => {
  beforeEach('loads', () => {
    cy.visit('data/stasg_missiv_00006.xml?mode=off&view=single&odd=rqzh')
  });

  it('Check meta title', () => {
    cy.title().should('not.be.empty')
    .should('eq', 'St. Galler Missiven: StadtASG Missive, Nr. 6');
  });

  it.skip('Check meta description', () => {
    cy.get('meta[name="description"]').should('have.attr', 'content').and('not.be.empty');
  });

  it('Document title is in the header', () => {
    cy.contains('h1', 'Ulrich Zeph an Bürgermeister und Rat zu St. Gallen').should('be.visible')
  });

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
    cy.get('pb-popover[data-ref="stadtasg-actors-148"]')
      .find('span[slot="alternate"]')
      .should('exist')
      .should('contain', 'Organisation: ')
      .should('contain', 'Bürgermeister und Rat zu St. Gallen')
  })


  it('Organisation of name Bürgermeister und Rat zu St. Gallen link opens register page', () => {
    cy.get('pb-popover[data-ref="stadtasg-actors-148"]')
      .find('a[href="../namen/Bürgermeister und Rat zu St. Gallen?key=stadtasg-actors-148"]')
      .eq(0)
      .invoke('removeAttr', 'target')
      .click({ force: true })
    cy.wait(10)

    // Check if exists headline “Name: Bürgermeister und Rat zu St. Gallen”  in new page
    cy.contains('h1', 'Name: Bürgermeister und Rat zu St. Gallen').should('be.visible')
      .should('have.id', 'locations');
  })

  it('Person of name Ulrich Zeph is highlighted in the text after checking name in register', () => {
    // clicking name in register list
    cy.get('pb-popover[data-ref=stadtasg-actors-6]')
      // checking highlight before
      .should('not.have.class', 'highlight')
    cy.get('li[data-ref=stadtasg-actors-6]')
      .find('div#checkboxContainer')
      .click();
    // checking highlight after
    cy.get('pb-popover[data-ref=stadtasg-actors-6]')
      .should('have.class', 'highlight')
  })

})